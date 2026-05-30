/// AudioService — streams mic PCM through the on-device CREPE TFLite model
/// and emits NoteResult events.
///
/// ── WHAT'S NEW ─────────────────────────────────────────────────────────────
/// Added a parallel `pitchFrames` stream that emits timestamped pitch frames:
///
///     PitchFrame(timeSec, hz, note, confidence)
///
/// These frames are used by the karaoke recording flow to group CREPE pitches
/// inside each word's time range AFTER Whisper finishes transcribing.
///
/// The existing `results` and `rawBytes` streams are unchanged so every other
/// part of the app (live note display, RMS bars, etc.) keeps working.
library;

import 'dart:async';
import 'dart:math';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'local_pitch_detector.dart';
import 'note_utils.dart';

/// One timestamped pitch reading produced by CREPE (or YIN fallback).
/// `timeSec` is RELATIVE to the moment recording started.
class PitchFrame {
  final double timeSec;
  final double hz;
  final String note;       // e.g. "G4", or "" if no signal
  final double confidence; // 0..1

  const PitchFrame({
    required this.timeSec,
    required this.hz,
    required this.note,
    required this.confidence,
  });
}

class AudioService {
  // ── Sample rate ───────────────────────────────────────────────────────────
  static const int _sampleRate = 16000;

  // ── CREPE constants ───────────────────────────────────────────────────────
  static const int _frameSize = 1024;
  static const int _hopSize   = 160;     // ~10 ms hop → 100 frames/sec
  static const int _nBins     = 360;
  static const double _minPitchHz = 32.70;
  static const double _maxPitchHz = 1975.5;

  // ── Tuning constants ──────────────────────────────────────────────────────
  static const double _minConfidence = 0.55;
  static const Duration _minEmitInterval = Duration(milliseconds: 80);

  // ── Internal state ────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  Interpreter? _interpreter;
  bool _crepeLoaded = false;
  bool _useLocalFallback = false;

  StreamSubscription<List<int>>? _audioSub;

  final _resultController     = StreamController<NoteResult?>.broadcast();
  final _bytesController      = StreamController<List<int>>.broadcast();
  final _pitchFrameController = StreamController<PitchFrame>.broadcast();

  Stream<NoteResult?> get results     => _resultController.stream;
  Stream<List<int>>   get rawBytes    => _bytesController.stream;
  Stream<PitchFrame>  get pitchFrames => _pitchFrameController.stream;

  bool _isRunning = false;
  bool _disposed  = false;

  final LocalPitchDetector _localDetector = LocalPitchDetector();
  double? _targetFreq;

  final List<double> _buffer = [];

  // Total samples consumed since recording started — used to compute the
  // absolute timestamp of each CREPE frame.
  int _samplesConsumed = 0;

  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> preloadCrepe() async {
    await _loadCrepeModel();
  }

  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    _targetFreq      = targetFreq;
    _lastEmit        = DateTime.fromMillisecondsSinceEpoch(0);
    _samplesConsumed = 0;
    _buffer.clear();
    _localDetector.reset();

    final status = await Permission.microphone.request();
    if (!status.isGranted || _disposed) return false;

    if (!_crepeLoaded) await _loadCrepeModel();

    if (!_crepeLoaded) {
      _useLocalFallback = true;
      print('⚠️ CREPE model not available — using local YIN fallback');
    } else {
      _useLocalFallback = false;
      print('✅ CREPE model ready — using on-device pitch detection');
    }

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );

    if (_disposed) return false;
    final stream = await _recorder.startStream(config);
    if (_disposed) {
      await _recorder.stop();
      return false;
    }

    _isRunning = true;

    _audioSub = stream.listen(
      (List<int> bytes) {
        if (_disposed) return;

        if (!_bytesController.isClosed) _bytesController.add(bytes);

        if (_useLocalFallback) {
          // YIN fallback path — no per-frame timestamp, so we synthesize one
          // from the running sample counter.
          final hz = _localDetector.process(bytes);
          _samplesConsumed += bytes.length ~/ 2; // 2 bytes per sample
          final t = _samplesConsumed / _sampleRate.toDouble();

          if (hz == null) return;
          if (hz > 0) {
            final result = analyzeFrequency(
              hz, targetFreq: _targetFreq, confidence: 1.0,
            );
            _pitchFrameController.add(PitchFrame(
              timeSec: t, hz: hz, note: result.fullName, confidence: 1.0,
            ));
            _emitIfReady(result);
          } else {
            _emitIfReady(null);
          }
        } else {
          _processPcmBytes(bytes);
        }
      },
      onError: (_) {
        if (!_disposed) _emitIfReady(null);
      },
    );

    return true;
  }

  // ── CREPE model loading ───────────────────────────────────────────────────

  Future<void> _loadCrepeModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/huni_crepe.tflite',
      );
      _crepeLoaded = true;
    } catch (e) {
      _crepeLoaded = false;
      _useLocalFallback = true;
      print('❌ Failed to load CREPE model: $e');
    }
  }

  // ── CREPE inference pipeline ──────────────────────────────────────────────

  void _processPcmBytes(List<int> bytes) {
    // PCM16 → float32, normalized to [-1, 1]
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int raw = bytes[i] | (bytes[i + 1] << 8);
      final int signed = raw > 32767 ? raw - 65536 : raw;
      _buffer.add(signed / 32768.0);
    }

    while (_buffer.length >= _frameSize) {
      final frame = _buffer.sublist(0, _frameSize);
      _buffer.removeRange(0, _hopSize);

      // Timestamp = number of samples consumed BEFORE this frame's center,
      // divided by the sample rate. Using the frame start as t is fine for
      // word-level grouping (we're not doing forced alignment).
      final tSec = _samplesConsumed / _sampleRate.toDouble();
      _samplesConsumed += _hopSize;

      final result = _runCrepe(frame, tSec);
      if (result != null) {
        _emitIfReady(result);
      } else {
        _emitIfReady(null);
      }
    }
  }

  NoteResult? _runCrepe(List<double> frame, double tSec) {
    if (_interpreter == null || !_crepeLoaded) return null;

    // Z-score normalize the frame (same prep as the original CREPE training).
    final mean = frame.reduce((a, b) => a + b) / frame.length;
    final centered = frame.map((s) => s - mean).toList();
    final variance =
        centered.map((s) => s * s).reduce((a, b) => a + b) / centered.length;
    final std = sqrt(variance);

    if (std <= 1e-6) return null; // silent frame
    final normalized = centered.map((s) => s / std).toList();

    final input = [normalized.map((s) => [s]).toList()];
    final output = [List<double>.filled(_nBins, 0.0)];

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ CREPE inference error: $e');
      return null;
    }

    final bins = output[0];

    int maxBin = 0;
    double maxConf = bins[0];
    for (int i = 1; i < _nBins; i++) {
      if (bins[i] > maxConf) {
        maxConf = bins[i];
        maxBin = i;
      }
    }

    if (maxConf < _minConfidence) return null;

    final cents = maxBin * (6000.0 / (_nBins - 1));
    final hz = _minPitchHz * pow(2, cents / 1200.0);

    if (hz < _minPitchHz || hz > _maxPitchHz) return null;

    final result = analyzeFrequency(
      hz.toDouble(), targetFreq: _targetFreq, confidence: maxConf,
    );

    // Broadcast the timestamped frame.
    if (!_pitchFrameController.isClosed) {
      _pitchFrameController.add(PitchFrame(
        timeSec: tSec,
        hz: hz.toDouble(),
        note: result.fullName,
        confidence: maxConf,
      ));
    }

    return result;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _emitIfReady(NoteResult? result) {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastEmit) < _minEmitInterval) return;
    _lastEmit = now;
    if (!_resultController.isClosed) _resultController.add(result);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _useLocalFallback = false;
    _buffer.clear();
    _localDetector.reset();

    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isRunning = false;

    _audioSub?.cancel();
    _audioSub = null;

    _resultController.close();
    _bytesController.close();
    _pitchFrameController.close();
    _buffer.clear();

    _interpreter?.close();
    _interpreter = null;
    _crepeLoaded = false;

    _recorder.stop().then((_) => _recorder.dispose()).ignore();
  }
}