/// AudioService — Pure Dart Real-Time Pitch Detection
/// Uses YIN algorithm (no TFLite, no native dependencies, no FFI)
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'note_utils.dart';

class AudioService {
  // ── Audio Constants ─────────────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const int _bufferSize = 2048;
  static const int _hopSize = 512;
  static const double _threshold = 0.15;
  static const double _minFreq = 50.0;
  static const double _maxFreq = 1500.0;

  // ── Smoothing ───────────────────────────────────────────────────────────────
  static const Duration _minEmitInterval = Duration(milliseconds: 80);
  static const int _medianWindowSize = 5;
  static const double _emaAlpha = 0.25;

  // ── State ───────────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  StreamController<NoteResult?>? _resultController;
  Stream<NoteResult?> get results {
    _resultController ??= StreamController<NoteResult?>.broadcast();
    return _resultController!.stream;
  }

  final _bytesController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get rawBytes => _bytesController.stream;

  bool _isRunning = false;

  double? _targetFreq;

  final List<double> _buffer = [];
  final List<double> _recentHz = [];
  double? _smoothedHz;
  double? _lastConfidence;

  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> preloadCrepe() async {
    // YIN doesn't need preloading, but this method exists for compatibility
  }

  /// Start recording and pitch detection
  /// [targetFreq] = optional target frequency for pitch matching
  /// [enableMonitoring] = whether to enable real-time voice monitoring (ignored in pure YIN mode)
  Future<bool> start({double? targetFreq, bool enableMonitoring = true}) async {
    if (_isRunning) return true;

    _targetFreq = targetFreq;
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    _buffer.clear();
    _recentHz.clear();
    _smoothedHz = null;
    _lastConfidence = null;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return false;
    }

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: true,
    );

    final stream = await _recorder.startStream(config);
    _isRunning = true;

    _audioSub = stream.listen(
      _processAudioChunk,
      onError: (error) {
        debugPrint('Stream error: $error');
      },
      onDone: () {
        _isRunning = false;
      },
    );

    return true;
  }

  /// Toggle real-time voice monitoring (no-op in pure YIN mode, kept for API compatibility)
  void setMonitoring(bool enabled) {
    // Pure YIN mode doesn't support real-time monitoring toggle
    // This method exists for API compatibility with the UI
    debugPrint('Monitoring set to: \$enabled (no-op in YIN mode)');
  }

  // ── Audio Processing ────────────────────────────────────────────────────────

  void _processAudioChunk(Uint8List bytes) {
    if (bytes.isEmpty) return;

    // Forward raw bytes for WAV saving
    _bytesController.add(bytes.toList());

    final byteData = ByteData.sublistView(bytes);
    final sampleCount = bytes.length ~/ 2;

    for (int i = 0; i < sampleCount; i++) {
      final int signed = byteData.getInt16(i * 2, Endian.little);
      _buffer.add(signed / 32768.0);
    }

    const maxBufferSize = _bufferSize * 4;
    if (_buffer.length > maxBufferSize) {
      _buffer.removeRange(0, _buffer.length - maxBufferSize);
    }

    while (_buffer.length >= _bufferSize) {
      final frame = Float64List(_bufferSize);
      for (int i = 0; i < _bufferSize; i++) {
        frame[i] = _buffer[i];
      }

      _buffer.removeRange(0, _hopSize);

      final hz = _yinPitchDetect(frame);

      if (hz != null && hz >= _minFreq && hz <= _maxFreq) {
        final confidence = _calculateConfidence(frame, hz);
        final result = analyzeFrequency(
          hz,
          targetFreq: _targetFreq,
          confidence: confidence,
        );
        _handleDetectedPitch(result);
      }
    }
  }

  // ── YIN Pitch Detection ─────────────────────────────────────────────────────

  double? _yinPitchDetect(List<double> samples) {
    final int tauMax = _bufferSize ~/ 2;
    final List<double> diffFunction = List.filled(tauMax, 0.0);

    final int safeMax = _bufferSize - tauMax;

    for (int tau = 1; tau < tauMax; tau++) {
      double diff = 0.0;
      for (int i = 0; i < safeMax; i++) {
        final double delta = samples[i] - samples[i + tau];
        diff += delta * delta;
      }
      diffFunction[tau] = diff;
    }

    final List<double> cmnd = List.filled(tauMax, 0.0);
    cmnd[0] = 1.0;
    double runningSum = 0.0;

    for (int tau = 1; tau < tauMax; tau++) {
      runningSum += diffFunction[tau];
      if (runningSum < 1e-10) {
        cmnd[tau] = 1.0;
      } else {
        cmnd[tau] = diffFunction[tau] * tau / runningSum;
      }
    }

    int? tauEstimate;
    for (int tau = 2; tau < tauMax - 1; tau++) {
      if (cmnd[tau] < _threshold) {
        if (cmnd[tau] < cmnd[tau - 1] && cmnd[tau] < cmnd[tau + 1]) {
          tauEstimate = tau;
          break;
        }
      }
    }

    if (tauEstimate == null) return null;

    final double betterTau;
    if (tauEstimate > 0 && tauEstimate < tauMax - 1) {
      final alpha = diffFunction[tauEstimate - 1];
      final beta = diffFunction[tauEstimate];
      final gamma = diffFunction[tauEstimate + 1];

      final denominator = alpha - 2 * beta + gamma;
      if (denominator.abs() > 1e-10) {
        final p = 0.5 * (alpha - gamma) / denominator;
        betterTau = tauEstimate + p;
      } else {
        betterTau = tauEstimate.toDouble();
      }
    } else {
      betterTau = tauEstimate.toDouble();
    }

    final hz = _sampleRate / betterTau;

    if (hz < _minFreq || hz > _maxFreq || hz.isNaN || hz.isInfinite) {
      return null;
    }

    return hz;
  }

  double _calculateConfidence(List<double> samples, double hz) {
    double maxAmp = 0;
    double sumSquares = 0;

    for (final s in samples) {
      final abs = s.abs();
      if (abs > maxAmp) maxAmp = abs;
      sumSquares += s * s;
    }

    final rms = sqrt(sumSquares / samples.length);
    double confidence = (rms * 4).clamp(0.3, 1.0);
    if (maxAmp < 0.01) confidence *= 0.5;

    return confidence;
  }

  // ── Temporal Smoothing ──────────────────────────────────────────────────────

  void _handleDetectedPitch(NoteResult result) {
    _recentHz.add(result.frequency);
    if (_recentHz.length > _medianWindowSize) {
      _recentHz.removeAt(0);
    }

    final medianHz = _calculateMedian(_recentHz);

    if (_smoothedHz == null) {
      _smoothedHz = medianHz;
    } else {
      _smoothedHz = _emaAlpha * medianHz + (1 - _emaAlpha) * _smoothedHz!;
    }

    if (_lastConfidence == null) {
      _lastConfidence = result.confidence;
    } else {
      _lastConfidence = 0.7 * result.confidence + 0.3 * _lastConfidence!;
    }

    final smoothedResult = analyzeFrequency(
      _smoothedHz!,
      targetFreq: _targetFreq,
      confidence: _lastConfidence!,
    );

    _emitIfReady(smoothedResult);
  }

  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[mid - 1] + sorted[mid]) / 2;
    }
    return sorted[mid];
  }

  // ── Rate Limiter ────────────────────────────────────────────────────────────

  void _emitIfReady(NoteResult? result) {
    if (_resultController == null || _resultController!.isClosed) return;

    final now = DateTime.now();
    if (now.difference(_lastEmit) < _minEmitInterval) return;
    _lastEmit = now;
    _resultController!.add(result);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _buffer.clear();
    _recentHz.clear();
    _smoothedHz = null;
    _lastConfidence = null;

    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
  }

  /// Full cleanup — call this in dispose()
  void dispose() {
    _isRunning = false;

    _audioSub?.cancel();
    _audioSub = null;

    _resultController?.close();
    _resultController = null;

    _bytesController.close();
    _buffer.clear();
    _recentHz.clear();

    _recorder.stop().ignore();
  }
}
