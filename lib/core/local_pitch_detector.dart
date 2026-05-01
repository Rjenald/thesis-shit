/// On-device pitch detector — YIN algorithm with accuracy improvements:
///
///  1. Hanning window  — tapers signal edges, reduces spectral leakage.
///  2. Stricter threshold (0.10) — far fewer false positives on noisy input.
///  3. Higher silence gate (0.012 RMS) — ignores background hiss.
///  4. Median filter over last 7 readings — eliminates single-frame spikes.
///  5. Pre-computed window coefficients — no per-call allocation overhead.
///
/// Reference: de Cheveigné & Kawahara (2002), "YIN, a fundamental frequency
/// estimator for speech and music".
library;

import 'dart:math';
import 'dart:typed_data';

class LocalPitchDetector {
  static const int sampleRate = 44100;

  // Analysis window: 2048 samples ≈ 46 ms  (good balance of latency / accuracy)
  static const int _windowSize = 2048;

  // Silence gate — skip analysis when the signal is below this RMS level.
  // 0.012 ≈ -38 dBFS; captures faint singing while rejecting background noise.
  static const double _silenceRms = 0.012;

  // YIN threshold — lower = stricter (fewer false detections).
  // 0.10 is recommended for monophonic voice; 0.18 caused too many false notes.
  static const double _yinThreshold = 0.10;

  // Vocal frequency range
  static const double _minHz = 60.0;   // ~B1 — below any bass singer
  static const double _maxHz = 1050.0; // ~C6 — above most sopranos

  // Median filter — size 7, report median of the last 7 valid detections.
  // Eliminates single-frame pitch spikes without adding noticeable latency.
  static const int _medianSize = 7;

  // ── Internal state ────────────────────────────────────────────────────────
  final List<double> _buf = [];
  final List<double> _recent = []; // last N non-zero frequency readings

  // Pre-computed Hanning window coefficients — allocated once.
  late final Float64List _hann;

  LocalPitchDetector() {
    _hann = Float64List(_windowSize);
    for (int i = 0; i < _windowSize; i++) {
      _hann[i] = 0.5 - 0.5 * cos(2.0 * pi * i / (_windowSize - 1));
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Feed raw PCM-16-LE bytes from the microphone.
  ///
  /// Returns:
  ///  - `null`  — buffer still filling (first ~46 ms after start)
  ///  - `0.0`   — signal present but no pitch detected (silence / noise)
  ///  - `> 0.0` — detected frequency in Hz (median-smoothed)
  double? process(List<int> pcmBytes) {
    // PCM 16-bit little-endian → normalised float [-1, 1]
    for (int i = 0; i + 1 < pcmBytes.length; i += 2) {
      int raw = pcmBytes[i] | (pcmBytes[i + 1] << 8);
      if (raw > 32767) raw -= 65536;
      _buf.add(raw / 32768.0);
    }

    if (_buf.length < _windowSize) return null; // still accumulating

    // Grab the latest windowSize samples for analysis
    final samples = _buf.sublist(_buf.length - _windowSize);

    // Trim the ring buffer — keep one window worth of overlap
    if (_buf.length > _windowSize * 2) {
      _buf.removeRange(0, _windowSize);
    }

    final raw = _yin(samples);

    if (raw <= 0.0) {
      // Silence or no pitch — don't add to history but still return 0
      return 0.0;
    }

    // Push into median filter
    _recent.add(raw);
    if (_recent.length > _medianSize) _recent.removeAt(0);

    if (_recent.length < 3) return raw; // too few data points for median yet

    // Return the median of collected readings
    final sorted = [..._recent]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Reset internal buffers (call when stopping or restarting recording).
  void reset() {
    _buf.clear();
    _recent.clear();
  }

  // ── YIN algorithm ───────────────────────────────────────────────────────────

  double _yin(List<double> x) {
    final n = x.length; // 2048
    final W = n ~/ 2;   // 1024 — half-window used for lag search

    // ── Step 1: RMS silence gate ────────────────────────────────────────────
    double sumSq = 0.0;
    for (final s in x) { sumSq += s * s; }
    if (sumSq / n < _silenceRms * _silenceRms) return 0.0;

    // ── Hanning window — taper edges to zero before computing differences ──
    //    This reduces spectral leakage and sharpens the CMNDF minimum.
    final w = Float64List(n);
    for (int i = 0; i < n; i++) { w[i] = x[i] * _hann[i]; }

    // ── Step 2: Difference function  d(τ) = Σ (w[j] − w[j+τ])² ───────────
    final d = Float64List(W);
    // d[0] stays 0
    for (int tau = 1; tau < W; tau++) {
      double sum = 0.0;
      for (int j = 0; j < W; j++) {
        final delta = w[j] - w[j + tau];
        sum += delta * delta;
      }
      d[tau] = sum;
    }

    // ── Step 3: Cumulative mean normalised difference (CMNDF) ───────────────
    //    d'(0) = 1;  d'(τ) = d(τ) × τ / Σ_{j=1}^{τ} d(j)
    final dp = Float64List(W);
    dp[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < W; tau++) {
      runningSum += d[tau];
      dp[tau] = runningSum > 0.0 ? d[tau] * tau / runningSum : 1.0;
    }

    // ── Step 4: First minimum of CMNDF below threshold ──────────────────────
    final minLag = (sampleRate / _maxHz).ceil(); // ≈ 42 samples
    final maxLag = (sampleRate / _minHz).floor(); // ≈ 735 samples

    int tauStar = -1;
    for (int tau = max(2, minLag); tau < min(W, maxLag + 1); tau++) {
      if (dp[tau] < _yinThreshold) {
        // Walk to the local minimum (not just the first crossing)
        int t = tau;
        while (t + 1 < W && dp[t + 1] < dp[t]) { t++; }
        tauStar = t;
        break;
      }
    }

    if (tauStar < 1) return 0.0; // no valid pitch found

    // ── Step 5: Parabolic interpolation for sub-sample precision ────────────
    double betterTau;
    if (tauStar > 0 && tauStar < W - 1) {
      final s0 = dp[tauStar - 1];
      final s1 = dp[tauStar];
      final s2 = dp[tauStar + 1];
      final denom = 2.0 * (2.0 * s1 - s2 - s0);
      betterTau = denom.abs() > 1e-10
          ? tauStar + (s2 - s0) / denom
          : tauStar.toDouble();
    } else {
      betterTau = tauStar.toDouble();
    }

    if (betterTau <= 0) return 0.0;

    final hz = sampleRate / betterTau;
    return (hz >= _minHz && hz <= _maxHz) ? hz : 0.0;
  }
}
