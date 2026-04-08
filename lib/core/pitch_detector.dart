/// YIN pitch detection algorithm implemented in pure Dart.
///
/// YIN (Yet another algorithm for fundamental frequency estimation) works by
/// finding the fundamental period (tau) in a time-domain audio buffer.
/// It is accurate for voice in the 80–1000 Hz range and runs in ~1 ms on
/// modern phones, making it ideal for real-time singing feedback.
///
/// Reference: de Cheveigné & Kawahara, 2002 — "YIN, a fundamental frequency
/// estimator for speech and music."
library;

import 'dart:typed_data';

class PitchDetector {
  /// Buffer size in samples. 4096 samples at 44100 Hz ≈ 93 ms.
  /// Larger = more accurate but slightly more latency.
  final int bufferSize;

  final int sampleRate;

  /// YIN threshold. Lower = more strict (fewer false positives, more misses).
  /// 0.10–0.15 is the recommended range for voice.
  final double threshold;

  /// Minimum detectable frequency in Hz.
  /// 80 Hz covers the lowest male singing notes.
  final double minFrequency;

  /// Maximum detectable frequency in Hz.
  /// 1100 Hz covers high soprano notes.
  final double maxFrequency;

  // Accumulated sample buffer (holds up to 2 × bufferSize so we can slide)
  final List<double> _sampleBuffer = [];

  PitchDetector({
    this.bufferSize = 4096,
    this.sampleRate = 44100,
    this.threshold = 0.12,
    this.minFrequency = 80.0,
    this.maxFrequency = 1100.0,
  });

  /// Feed raw PCM bytes (16-bit signed little-endian mono) into the detector.
  /// Returns a detected frequency in Hz, or null if no clear pitch found.
  double? addPcmBytes(Uint8List bytes) {
    // Convert int16 LE bytes → normalized doubles in [-1.0, 1.0]
    final bd = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      _sampleBuffer.add(bd.getInt16(i, Endian.little) / 32768.0);
    }

    // Wait until we have a full window
    if (_sampleBuffer.length < bufferSize) return null;

    // Take the newest bufferSize samples for analysis
    final window = _sampleBuffer.sublist(_sampleBuffer.length - bufferSize);

    // Slide: keep only the last half-buffer so next call overlaps by 50%
    if (_sampleBuffer.length > bufferSize) {
      _sampleBuffer.removeRange(0, _sampleBuffer.length - bufferSize ~/ 2);
    }

    return _yin(window);
  }

  /// Run YIN on a float buffer. Returns Hz or null.
  double? _yin(List<double> buffer) {
    final halfSize = bufferSize ~/ 2;
    final yinBuffer = List<double>.filled(halfSize, 0.0);

    // ── Step 1: Difference function ──────────────────────────────────────────
    // d[tau] = Σ (x[j] − x[j+tau])²  for j = 0..(halfSize−1)
    for (int tau = 1; tau < halfSize; tau++) {
      double sum = 0.0;
      for (int j = 0; j < halfSize; j++) {
        final delta = buffer[j] - buffer[j + tau];
        sum += delta * delta;
      }
      yinBuffer[tau] = sum;
    }

    // ── Step 2: Cumulative mean normalized difference ─────────────────────
    // d'[0] = 1.0
    // d'[tau] = d[tau] / ((1/tau) * Σ d[j] for j=1..tau)
    yinBuffer[0] = 1.0;
    double runningSum = 0.0;
    for (int tau = 1; tau < halfSize; tau++) {
      runningSum += yinBuffer[tau];
      if (runningSum == 0.0) {
        yinBuffer[tau] = 1.0;
      } else {
        yinBuffer[tau] *= tau / runningSum;
      }
    }

    // ── Step 3: Absolute threshold ────────────────────────────────────────
    // Find the first tau where d'[tau] dips below `threshold`.
    // Then slide to the local minimum of that dip.
    final tauMin = sampleRate ~/ maxFrequency; // smallest valid tau
    final tauMax = sampleRate ~/ minFrequency; // largest valid tau

    int tau = tauMin;
    while (tau < tauMax && tau < halfSize - 1) {
      if (yinBuffer[tau] < threshold) {
        // Slide to the local minimum
        while (tau + 1 < halfSize && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        break;
      }
      tau++;
    }

    // No pitch found if we hit the ceiling
    if (tau >= tauMax || yinBuffer[tau] >= threshold) return null;

    // ── Step 4: Parabolic interpolation ──────────────────────────────────
    // Refine tau to sub-sample accuracy.
    double betterTau;
    if (tau > 0 && tau < halfSize - 1) {
      final s0 = yinBuffer[tau - 1];
      final s1 = yinBuffer[tau];
      final s2 = yinBuffer[tau + 1];
      final denom = 2.0 * s1 - s2 - s0;
      betterTau = denom == 0.0
          ? tau.toDouble()
          : tau + (s2 - s0) / (2.0 * denom);
    } else {
      betterTau = tau.toDouble();
    }

    return sampleRate / betterTau;
  }

  /// Clear the internal sample buffer (call when stopping/restarting).
  void reset() => _sampleBuffer.clear();
}
