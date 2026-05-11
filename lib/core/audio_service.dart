/// AudioService — streams mic PCM through the on-device CREPE TFLite model
/// and emits NoteResult events.
///
/// Primary:  On-device CREPE TFLite (huni_crepe.tflite) — highest accuracy.
/// Fallback: On-device YIN pitch detector — works if model fails to load.
///
/// No WebSocket or internet connection required.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'local_pitch_detector.dart';
import 'note_utils.dart';

class AudioService {
  // ── Sample rate ─────────────────────────────────────────────────────────────
  // CREPE requires exactly 16kHz. We record at 16kHz directly.
  static const int _sampleRate = 16000;

  // ── CREPE constants ─────────────────────────────────────────────────────────
  // These must match exactly how the model was trained in Colab.
  static const int _frameSize = 1024;   // samples per CREPE input frame
  static const int _hopSize   = 160;    // samples to advance each frame (10ms)
  static const int _nBins     = 360;    // CREPE output bins
  static const double _minPitchHz = 32.70;   // C1 — lowest CREPE can detect
  static const double _maxPitchHz = 1975.5;  // B6 — highest CREPE can detect

  // ── Tuning constants ────────────────────────────────────────────────────────

<<<<<<< HEAD
  /// Time to wait for the first WebSocket message before falling back to
  /// local detection.  250 ms is enough to detect a live server; any longer
  /// just delays the start of on-device detection when no server is running.
  static const Duration _wsFallbackDelay = Duration(milliseconds: 250);

=======
>>>>>>> origin/yosef
  /// Minimum CREPE confidence to accept a result.
  /// Below this = noise, silence, or uncertain — discard.
  static const double _minConfidence = 0.55;

  /// Minimum time between emitted results (rate limiter).
  /// 80 ms = ~12 Hz update rate. Fast enough for UI, not too noisy.
  static const Duration _minEmitInterval = Duration(milliseconds: 80);

  // ── Internal state ──────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  Interpreter? _interpreter;           // CREPE TFLite model
  bool _crepeLoaded = false;           // true if model loaded successfully
  bool _useLocalFallback = false;      // true if falling back to YIN

  StreamSubscription<List<int>>? _audioSub;

  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  // Raw PCM bytes stream — for external consumers
  final _bytesController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get rawBytes => _bytesController.stream;

  bool _isRunning = false;
  bool _disposed  = false;

  final LocalPitchDetector _localDetector = LocalPitchDetector();
  double? _targetFreq;

  // Rolling audio buffer — accumulates PCM samples between chunks
  final List<double> _buffer = [];

  // Rate-limiter state
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Pre-load the CREPE model without starting the microphone.
  /// Call this in initState() so the model is ready when user hits Record.
  Future<void> preloadCrepe() async {
    await _loadCrepeModel();
  }

  /// Request mic permission, load CREPE model, start streaming.
  /// Returns false only if microphone permission is denied.
  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    _targetFreq  = targetFreq;
    _lastEmit    = DateTime.fromMillisecondsSinceEpoch(0);
    _buffer.clear();
    _localDetector.reset();

    // ── 1. Mic permission ───────────────────────────────────────────────────
    final status = await Permission.microphone.request();
    if (!status.isGranted || _disposed) return false;

    // ── 2. Load CREPE TFLite model (if not already loaded) ─────────────────
    if (!_crepeLoaded) {
      await _loadCrepeModel();
    }

    if (!_crepeLoaded) {
      // Model failed to load — use YIN local detector as fallback
      _useLocalFallback = true;
      print('⚠️ CREPE model not available — using local YIN fallback');
    } else {
      _useLocalFallback = false;
      print('✅ CREPE model ready — using on-device pitch detection');
    }

    // ── 3. Start microphone PCM stream at 16kHz ─────────────────────────────
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,          // 16kHz — required by CREPE
      numChannels: 1,                   // mono
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

    // ── 4. Process PCM bytes as they arrive from the microphone ─────────────
    _audioSub = stream.listen(
      (List<int> bytes) {
        if (_disposed) return;

        // Broadcast raw PCM bytes to any external listeners
        if (!_bytesController.isClosed) {
          _bytesController.add(bytes);
        }

        if (_useLocalFallback) {
          // ── YIN fallback path ─────────────────────────────────────────────
          final hz = _localDetector.process(bytes);
          if (hz == null) return; // buffer not full yet
          if (hz > 0) {
            _emitIfReady(analyzeFrequency(
              hz,
              targetFreq: _targetFreq,
              confidence: 1.0,
            ));
          } else {
            _emitIfReady(null); // silence
          }
        } else {
          // ── CREPE on-device path ──────────────────────────────────────────
          _processPcmBytes(bytes);
        }
      },
      onError: (_) {
        if (!_disposed) _emitIfReady(null);
      },
    );

    return true;
  }

  // ── CREPE model loading ─────────────────────────────────────────────────────

  Future<void> _loadCrepeModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/huni_crepe.tflite',
      );
      _crepeLoaded = true;
      print('✅ CREPE TFLite model loaded');
      print('   Input shape  : ${_interpreter!.getInputTensor(0).shape}');
      print('   Output shape : ${_interpreter!.getOutputTensor(0).shape}');
    } catch (e) {
      _crepeLoaded = false;
      _useLocalFallback = true;
      print('❌ Failed to load CREPE model: $e');
      print('   Falling back to local YIN detector');
    }
  }

  // ── CREPE inference pipeline ────────────────────────────────────────────────

  /// Convert raw PCM bytes → float samples → buffer → run CREPE per frame.
  void _processPcmBytes(List<int> bytes) {
    // Step 1: Convert PCM16 bytes to float32 samples
    // PCM16 = 2 bytes per sample, little-endian, range -32768 to 32767
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      final int raw = bytes[i] | (bytes[i + 1] << 8);
      // Convert unsigned to signed
      final int signed = raw > 32767 ? raw - 65536 : raw;
      // Normalize to -1.0 to 1.0
      _buffer.add(signed / 32768.0);
    }

    // Step 2: Process every complete 1024-sample frame
    while (_buffer.length >= _frameSize) {
      // Extract one frame
      final frame = _buffer.sublist(0, _frameSize);

      // Slide window forward by hopSize (10ms)
      _buffer.removeRange(0, _hopSize);

      // Step 3: Run CREPE on this frame
      final result = _runCrepe(frame);

      if (result != null) {
        _emitIfReady(result);
      } else {
        _emitIfReady(null);
      }
    }
  }

  /// Run CREPE model on one 1024-sample frame.
  /// Returns a NoteResult or null if no pitch detected.
  NoteResult? _runCrepe(List<double> frame) {
    if (_interpreter == null || !_crepeLoaded) return null;

    // Step 1: Normalize the frame
    // Subtract mean, divide by std — same as training preprocessing
    double mean = frame.reduce((a, b) => a + b) / frame.length;
    List<double> centered = frame.map((s) => s - mean).toList();

    double variance = centered
        .map((s) => s * s)
        .reduce((a, b) => a + b) / centered.length;
    double std = sqrt(variance);

    List<double> normalized;
    if (std > 1e-6) {
      normalized = centered.map((s) => s / std).toList();
    } else {
      // Silent frame — std is near zero, no signal
      return null;
    }

    // Step 2: Prepare input tensor — shape [1, 1024, 1]
    // CREPE expects (batch, samples, channels)
    final input = [
      normalized.map((s) => [s]).toList()
    ];

    // Step 3: Prepare output tensor — shape [1, 360]
    final output = [List<double>.filled(_nBins, 0.0)];

    // Step 4: Run inference
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ CREPE inference error: $e');
      return null;
    }

    // Step 5: Read 360 bin probabilities
    final bins = output[0];

    // Step 6: Find the bin with highest confidence
    int maxBin = 0;
    double maxConf = bins[0];
    for (int i = 1; i < _nBins; i++) {
      if (bins[i] > maxConf) {
        maxConf = bins[i];
        maxBin  = i;
      }
    }

    // Step 7: Gate on minimum confidence
    // Below 0.55 = noise, silence, or uncertain transition
    if (maxConf < _minConfidence) return null;

    // Step 8: Convert bin index → Hz
    // CREPE covers C1 (32.7 Hz) to B6 (1975.5 Hz) across 360 bins
    final cents = maxBin * (6000.0 / (_nBins - 1));
    final hz    = _minPitchHz * pow(2, cents / 1200.0);

    // Step 9: Sanity check — pitch must be in human singing range
    if (hz < _minPitchHz || hz > _maxPitchHz) return null;

    // Step 10: Convert Hz → NoteResult (note name, cents, flat/sharp)
    return analyzeFrequency(
      hz,
      targetFreq: _targetFreq,
      confidence: maxConf,
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Emit a result only if the rate-limiter allows it.
  /// Prevents flooding the UI at 100+ Hz.
  void _emitIfReady(NoteResult? result) {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastEmit) < _minEmitInterval) return;
    _lastEmit = now;
    _resultController.add(result);
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Stop recording. Safe to call multiple times.
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

  /// Dispose the service. Safe to call even if stop() was not called.
  void dispose() {
    if (_disposed) return;
    _disposed   = true;
    _isRunning  = false;

    _audioSub?.cancel();
    _audioSub = null;

    _resultController.close();
    _bytesController.close();
    _buffer.clear();

    _interpreter?.close();
    _interpreter = null;
    _crepeLoaded = false;

    _recorder.stop().then((_) => _recorder.dispose()).ignore();
  }
}