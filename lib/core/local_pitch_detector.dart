/// On-device pitch detector using the YIN algorithm.
///
/// Runs entirely in Dart — no server required.
/// Accuracy is suitable for voice pitch feedback (within ~15 cents).
///
/// Reference: de Cheveigné & Kawahara (2002), "YIN, a fundamental frequency
/// estimator for speech and music".
library;

import 'dart:math';
import 'dart:typed_data';

class LocalPitchDetector {
  static const int sampleRate = 44100;

  // How many PCM samples we collect before running detection (~46 ms)
  static const int _windowSize = 2048;

  // Minimum RMS to consider a signal non-silent
  static const double _silenceRms = 0.008;

  // YIN threshold — lower = stricter (0.10–0.20 typical)
  static const double _yinThreshold = 0.15;

  // Voice frequency bounds
  static const double _minHz = 60.0; // ~B1  (below any singing bass)
  static const double _maxHz = 1050.0; // ~C6 (above most sopranos)

  final List<double> _buf = [];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Feed raw PCM-16-LE bytes from the microphone.
  /// Returns detected frequency in Hz, or `null` if the buffer isn't full yet,
  /// or `0.0` if the signal is silent / no pitch detected.
  double? process(List<int> pcmBytes) {
    // Convert PCM16 LE → normalized float
    for (int i = 0; i + 1 < pcmBytes.length; i += 2) {
      int raw = pcmBytes[i] | (pcmBytes[i + 1] << 8);
      if (raw > 32767) raw -= 65536;
      _buf.add(raw / 32768.0);
    }

    if (_buf.length < _windowSize) return null; // still accumulating

    // Slide: keep the last windowSize samples, drop the oldest half
    final samples = _buf.sublist(_buf.length - _windowSize);
    if (_buf.length > _windowSize * 2) {
      _buf.removeRange(0, _windowSize);
    }

    return _yin(samples);
  }

  /// Reset the internal sample buffer (call on stop).
  void reset() => _buf.clear();

  // ── YIN implementation ──────────────────────────────────────────────────────

  static double _yin(List<double> x) {
    final n = x.length; // 2048
    final W = n ~/ 2; // 1024 — half window for lag search

    // ── Step 1: RMS silence check ────────────────────────────────────────────
    double sumSq = 0.0;
    for (final s in x) {
      sumSq += s * s;
    }
    final rms = sqrt(sumSq / n);
    if (rms < _silenceRms) return 0.0;

    // ── Step 2: Difference function d(τ) ────────────────────────────────────
    // d(τ) = Σ_{j=0}^{W-1} (x[j] - x[j+τ])²
    final d = Float64List(W);
    d[0] = 0.0;
    for (int tau = 1; tau < W; tau++) {
      double sum = 0.0;
      for (int j = 0; j < W; j++) {
        final delta = x[j] - x[j + tau];
        sum += delta * delta;
      }
      d[tau] = sum;
    }

    // ── Step 3: Cumulative mean normalised difference (CMNDF) ─────────────
    // d'(0) = 1
    // d'(τ) = d(τ) / [(1/τ) · Σ_{j=1}^{τ} d(j)]
    final dp = Float64List(W);
    dp[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < W; tau++) {
      runningSum += d[tau];
      dp[tau] = runningSum > 0 ? d[tau] * tau / runningSum : 1.0;
    }

    // ── Step 4: First minimum below threshold ────────────────────────────────
    final minLag = (sampleRate / _maxHz).ceil(); // ~42 samples
    final maxLag = (sampleRate / _minHz).floor(); // ~735 samples

    int tauStar = -1;
    for (int tau = max(2, minLag); tau < min(W, maxLag + 1); tau++) {
      if (dp[tau] < _yinThreshold) {
        // Walk to the local minimum
        int t = tau;
        while (t + 1 < W && dp[t + 1] < dp[t]) { t++; }
        tauStar = t;
        break;
      }
    }

    if (tauStar < 1) return 0.0; // no pitch found

    // ── Step 5: Parabolic interpolation for sub-sample accuracy ─────────────
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
    // Clamp to valid vocal range
    if (hz < _minHz || hz > _maxHz) return 0.0;
    return hz;
  }
}
