/// On-device pitch detector — YIN algorithm with accuracy improvements:
///
///  1. Hanning window  — tapers signal edges, reduces spectral leakage.
///  2. Threshold 0.10  — low false-positive rate on voice input.
///  3. Silence gate 0.015 RMS — ignores background hiss.
///  4. Sub-octave correction — fixes common "detect 2nd harmonic" error:
///     after finding a candidate period τ, checks whether 2τ also satisfies
///     the threshold; if so, prefers the lower fundamental frequency.
///  5. Median filter over last 5 readings — eliminates single-frame spikes
///     while responding faster than the previous 7-sample filter.
///  6. Window size 4096 — ~93 ms, gives sub-cent resolution down to 70 Hz.
///  7. Pre-computed Hanning coefficients — no per-call allocation overhead.
///
/// Reference: de Cheveigné & Kawahara (2002), "YIN, a fundamental frequency
/// estimator for speech and music".
library;

import 'dart:math';
import 'dart:typed_data';

class LocalPitchDetector {
  static const int sampleRate = 44100;

  // ── Analysis window ──────────────────────────────────────────────────────────
  // 4096 samples ≈ 93 ms  — better low-frequency resolution than 2048.
  // Half-window (W=2048) gives lag search up to ~735 samples → down to ~60 Hz.
  static const int _windowSize = 4096;

  // ── Silence gate ─────────────────────────────────────────────────────────────
  // 0.015 RMS ≈ -36 dBFS.  Ignores mic hiss; catches faint singing.
  static const double _silenceRms = 0.015;

  // ── YIN threshold ─────────────────────────────────────────────────────────────
  // 0.10 — recommended for monophonic voice (de Cheveigné & Kawahara §6.2).
  // Lower → stricter (fewer false detections, more "no signal" during soft notes).
  static const double _yinThreshold = 0.10;

  // ── Sub-octave correction tolerance ──────────────────────────────────────────
  // When checking 2τ as the true fundamental, accept it if its CMNDF value
  // is within this factor of the threshold.
  static const double _octaveCorrFactor = 1.8;

  // ── Vocal frequency range ─────────────────────────────────────────────────────
  static const double _minHz = 60.0;   // ~B1 — below any bass singer
  static const double _maxHz = 1050.0; // ~C6 — above most sopranos

  // ── Median filter ─────────────────────────────────────────────────────────────
  // 5 readings × ~80 ms each = 400 ms of smoothing — fast enough for live karaoke.
  static const int _medianSize = 5;

  // ── Internal state ────────────────────────────────────────────────────────────
  final List<double> _buf    = [];
  final List<double> _recent = []; // last N non-zero frequency readings

  // Pre-computed Hanning window — allocated once at construction.
  late final Float64List _hann;

  LocalPitchDetector() {
    _hann = Float64List(_windowSize);
    for (int i = 0; i < _windowSize; i++) {
      _hann[i] = 0.5 - 0.5 * cos(2.0 * pi * i / (_windowSize - 1));
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Feed raw PCM-16-LE bytes from the microphone.
  ///
  /// Returns:
  ///  - `null`  — buffer still filling (first ~93 ms after start)
  ///  - `0.0`   — signal present but no pitch detected (silence / noise)
  ///  - `> 0.0` — detected frequency in Hz (octave-corrected, median-smoothed)
  double? process(List<int> pcmBytes) {
    // PCM 16-bit little-endian → normalised float [-1, 1]
    for (int i = 0; i + 1 < pcmBytes.length; i += 2) {
      int raw = pcmBytes[i] | (pcmBytes[i + 1] << 8);
      if (raw > 32767) raw -= 65536;
      _buf.add(raw / 32768.0);
    }

    if (_buf.length < _windowSize) return null; // buffer still filling

    // Grab the latest windowSize samples
    final samples = _buf.sublist(_buf.length - _windowSize);

    // Trim ring buffer — keep one window of overlap
    if (_buf.length > _windowSize * 2) {
      _buf.removeRange(0, _windowSize);
    }

    final raw = _yin(samples);

    if (raw <= 0.0) {
      return 0.0; // silence or no clean pitch
    }

    // Median filter
    _recent.add(raw);
    if (_recent.length > _medianSize) _recent.removeAt(0);

    if (_recent.length < 3) return raw; // too few samples for a reliable median

    final sorted = [..._recent]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Reset internal buffers (call when stopping or restarting recording).
  void reset() {
    _buf.clear();
    _recent.clear();
  }

  // ── YIN algorithm with sub-octave correction ──────────────────────────────────

  double _yin(List<double> x) {
    final n = x.length; // 4096
    final W = n ~/ 2;   // 2048 — lag search range

    // ── Step 1: RMS silence gate ───────────────────────────────────────────────
    double sumSq = 0.0;
    for (final s in x) {
      sumSq += s * s;
    }
    if (sumSq / n < _silenceRms * _silenceRms) return 0.0;

    // ── Hanning window ─────────────────────────────────────────────────────────
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = x[i] * _hann[i];
    }

    // ── Step 2: Difference function  d(τ) = Σ (w[j] − w[j+τ])² ──────────────
    final d = Float64List(W);
    for (int tau = 1; tau < W; tau++) {
      double sum = 0.0;
      for (int j = 0; j < W; j++) {
        final delta = w[j] - w[j + tau];
        sum += delta * delta;
      }
      d[tau] = sum;
    }

    // ── Step 3: Cumulative mean normalised difference (CMNDF) ──────────────────
    final dp = Float64List(W);
    dp[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < W; tau++) {
      runningSum += d[tau];
      dp[tau] = runningSum > 0.0 ? d[tau] * tau / runningSum : 1.0;
    }

    // ── Step 4: Find first CMNDF minimum below threshold ───────────────────────
    final minLag = (sampleRate / _maxHz).ceil(); // ≈ 42 samples
    final maxLag = (sampleRate / _minHz).floor(); // ≈ 735 samples

    int tauStar = -1;
    for (int tau = max(2, minLag); tau < min(W, maxLag + 1); tau++) {
      if (dp[tau] < _yinThreshold) {
        // Walk to the local minimum (not just the first threshold crossing)
        int t = tau;
        while (t + 1 < W && dp[t + 1] < dp[t]) {
          t++;
        }
        tauStar = t;
        break;
      }
    }

    if (tauStar < 1) return 0.0;

    // ── Step 4b: Sub-octave correction ─────────────────────────────────────────
    // YIN sometimes locks to the 2nd harmonic (τ/2, frequency × 2).
    // If doubling τ still satisfies the threshold (with some tolerance), it
    // means the lower frequency (2τ = true fundamental) is also periodic.
    // In that case, prefer the lower, correct fundamental.
    final doubleTau = tauStar * 2;
    if (doubleTau < W) {
      // Sample the CMNDF around doubleTau (average 3 points for stability)
      final left  = doubleTau > 0     ? dp[doubleTau - 1] : dp[doubleTau];
      final mid   = dp[doubleTau];
      final right = doubleTau < W - 1 ? dp[doubleTau + 1] : dp[doubleTau];
      final dpAtDouble = (left + mid + right) / 3.0;

      if (dpAtDouble < _yinThreshold * _octaveCorrFactor) {
        // Lower fundamental is also valid → use it to avoid octave-high error.
        tauStar = doubleTau;
      }
    }

    // ── Step 5: Parabolic interpolation for sub-sample precision ───────────────
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
