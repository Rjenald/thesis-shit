/// Real-time pitch detection using the actual CREPE model running ON THE
/// DEVICE — no server, no network. Loads assets/models/huni_crepe.tflite
/// (standard CREPE architecture: 1024-sample @16kHz input, 360-bin pitch
/// salience output) and runs inference locally via tflite_flutter.
///
/// Includes a simple, real preprocessing chain before each frame is fed to
/// the model: DC-offset removal, a first-order pre-emphasis high-pass
/// filter, and an RMS-energy VAD gate that skips inference entirely on
/// near-silent frames (saves battery and avoids feeding the model noise).
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'note_utils.dart';
import 'pitch_detection_service.dart';

class OnDeviceCrepeService implements PitchDetectionService {
  static const _modelAsset = 'assets/models/huni_crepe.tflite';
  static const _frameSize = 1024; // CREPE's fixed input width
  static const _sampleRate = 16000;
  // How often to run inference — full CREPE is heavy for a phone CPU, so
  // this trades detection cadence for staying smooth. Real latency varies
  // by device (see thesis limitation on real-time performance on mobile).
  static const _inferenceInterval = Duration(milliseconds: 200);
  static const _confidenceThreshold = 0.5;
  // RMS floor below which a frame is treated as silence/noise and skipped.
  static const _vadRmsFloor = 0.01;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  Interpreter? _interpreter;

  StreamController<NoteResult?>? _resultController;
  @override
  Stream<NoteResult?> get results {
    _resultController ??= StreamController<NoteResult?>.broadcast();
    return _resultController!.stream;
  }

  final _bytesController = StreamController<List<int>>.broadcast();
  @override
  Stream<List<int>> get rawBytes => _bytesController.stream;

  bool _isRunning = false;
  double? _targetFreq;

  // Rolling PCM buffer (int16 samples) — always keep at least _frameSize.
  final List<int> _pcmBuffer = [];
  DateTime _lastInference = DateTime.fromMillisecondsSinceEpoch(0);
  double _prevSampleForPreEmphasis = 0;

  /// Returns false if the model can't be loaded or the mic permission is
  /// denied — caller should fall back to the network CREPE service or YIN.
  @override
  Future<bool> start({double? targetFreq, bool enableMonitoring = true}) async {
    if (_isRunning) return true;
    _targetFreq = targetFreq;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    // Plain multi-threaded CPU inference (XNNPACK, tflite_flutter's default)
    // — no NNAPI delegate. NNAPI needs a real hardware HAL and reliably
    // fails interpreter creation on emulators/many devices that don't have
    // one; CPU-only is what actually works everywhere.
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
      _interpreter!.allocateTensors();
    } catch (e) {
      debugPrint('On-device CREPE model load failed: $e');
      _interpreter = null;
      return false;
    }

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      audioInterruption: AudioInterruptionMode.none,
      iosConfig: const IosRecordConfig(
        categoryOptions: [
          IosAudioCategoryOption.mixWithOthers,
          IosAudioCategoryOption.defaultToSpeaker,
          IosAudioCategoryOption.allowBluetooth,
          IosAudioCategoryOption.allowBluetoothA2DP,
        ],
      ),
    );

    final Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(config);
    } catch (e) {
      debugPrint('On-device CREPE mic start failed: $e');
      _interpreter?.close();
      _interpreter = null;
      return false;
    }

    _pcmBuffer.clear();
    _prevSampleForPreEmphasis = 0;
    _isRunning = true;
    _audioSub = stream.listen(
      _onAudioChunk,
      onError: (e) => debugPrint('On-device CREPE mic stream error: $e'),
      onDone: () => _isRunning = false,
    );

    return true;
  }

  void _onAudioChunk(Uint8List bytes) {
    _bytesController.add(bytes.toList());

    // int16 little-endian -> sample list
    final byteData = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      _pcmBuffer.add(byteData.getInt16(i, Endian.little));
    }
    // Cap buffer growth — only need the most recent frame's worth.
    if (_pcmBuffer.length > _frameSize * 4) {
      _pcmBuffer.removeRange(0, _pcmBuffer.length - _frameSize * 4);
    }

    if (_pcmBuffer.length < _frameSize) return;
    final now = DateTime.now();
    if (now.difference(_lastInference) < _inferenceInterval) return;
    _lastInference = now;

    final frame = _pcmBuffer.sublist(_pcmBuffer.length - _frameSize);
    _runInference(frame);
  }

  void _runInference(List<int> intFrame) {
    if (_interpreter == null || _resultController == null || _resultController!.isClosed) {
      return;
    }

    final frame = _computeFrame(intFrame, _prevSampleForPreEmphasis);
    _prevSampleForPreEmphasis = frame.prevSample;

    if (frame.frequency <= 0) {
      _resultController!.add(NoteResult.silent());
      return;
    }

    _resultController!.add(analyzeFrequency(
      frame.frequency,
      targetFreq: _targetFreq,
      confidence: frame.confidence,
    ));
  }

  /// Core per-frame CREPE pipeline, shared by the live stream ([_runInference])
  /// and the offline batch pass ([analyzeOffline]): pre-emphasis + z-score
  /// normalization, VAD gate, interpreter inference, and sub-bin peak decode.
  /// [prevSample] carries the pre-emphasis filter's state across frames —
  /// pass in the previous call's returned prevSample to keep it continuous.
  _FrameResult _computeFrame(List<int> intFrame, double prevSample) {
    // int16 -> float32 [-1, 1], DC removal, pre-emphasis high-pass, then
    // z-score normalization (CREPE's expected input distribution).
    final floats = Float64List(_frameSize);
    double mean = 0;
    double prev = prevSample;
    for (var i = 0; i < _frameSize; i++) {
      final sample = intFrame[i] / 32768.0;
      final emphasized = sample - 0.97 * prev;
      prev = sample;
      floats[i] = emphasized;
      mean += emphasized;
    }
    mean /= _frameSize;

    double sumSquares = 0;
    for (var i = 0; i < _frameSize; i++) {
      final centered = floats[i] - mean;
      floats[i] = centered;
      sumSquares += centered * centered;
    }
    final rms = math.sqrt(sumSquares / _frameSize);

    // VAD gate: skip inference on near-silent/noise-floor frames entirely.
    if (rms < _vadRmsFloor) {
      return _FrameResult(frequency: 0, confidence: 0, prevSample: prev);
    }

    final std = rms.clamp(1e-8, double.infinity);
    final input = [List<double>.generate(_frameSize, (i) => floats[i] / std)];
    final output = [List<double>.filled(360, 0.0)];

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('CREPE inference error: $e');
      return _FrameResult(frequency: 0, confidence: 0, prevSample: prev);
    }

    final activation = output[0];
    var peakBin = 0;
    var peakVal = activation[0];
    for (var i = 1; i < activation.length; i++) {
      if (activation[i] > peakVal) {
        peakVal = activation[i];
        peakBin = i;
      }
    }

    if (peakVal < _confidenceThreshold) {
      return _FrameResult(
        frequency: 0,
        confidence: peakVal.toDouble(),
        prevSample: prev,
      );
    }

    // Weighted average over a small window around the peak for sub-bin
    // precision (standard CREPE decoding).
    const window = 4;
    final lo = math.max(0, peakBin - window);
    final hi = math.min(activation.length - 1, peakBin + window);
    double weightedBin = 0, weightSum = 0;
    for (var i = lo; i <= hi; i++) {
      weightedBin += i * activation[i];
      weightSum += activation[i];
    }
    final bin = weightSum > 0 ? weightedBin / weightSum : peakBin.toDouble();

    final cents = bin * 20.0 + 1997.3794084376191;
    final freq = 10.0 * math.pow(2.0, cents / 1200.0);

    return _FrameResult(
      frequency: freq.toDouble(),
      confidence: peakVal.toDouble(),
      prevSample: prev,
    );
  }

  /// Runs CREPE over an entire pre-recorded PCM16 buffer instead of live mic
  /// input — for post-recording analysis (e.g. a full-recording summary)
  /// rather than real-time feedback. Loads its own interpreter on first call
  /// if one isn't already running; call [dispose] afterwards to release it.
  Future<List<PitchFrame>> analyzeOffline(
    List<int> pcm16Samples, {
    int hopMs = 100,
  }) async {
    if (_interpreter == null) {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
      _interpreter!.allocateTensors();
    }

    final hopSamples = math.max(1, (_sampleRate * hopMs / 1000).round());
    final frames = <PitchFrame>[];
    double prevSample = 0;

    for (
      var start = 0;
      start + _frameSize <= pcm16Samples.length;
      start += hopSamples
    ) {
      final frame = pcm16Samples.sublist(start, start + _frameSize);
      final result = _computeFrame(frame, prevSample);
      prevSample = result.prevSample;
      frames.add(PitchFrame(
        timeMs: (start / _sampleRate * 1000).round(),
        frequency: result.frequency,
        confidence: result.confidence,
      ));
    }

    return frames;
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    _interpreter?.close();
    _interpreter = null;
    _pcmBuffer.clear();
  }

  @override
  void dispose() {
    _isRunning = false;
    _audioSub?.cancel();
    _audioSub = null;
    _interpreter?.close();
    _interpreter = null;
    _resultController?.close();
    _resultController = null;
    _bytesController.close();
    _recorder.stop().ignore();
  }
}

/// Internal result of one CREPE frame inference, before it's turned into a
/// [NoteResult] (live path) or a [PitchFrame] (offline batch path).
class _FrameResult {
  final double frequency; // 0 = no signal
  final double confidence;
  final double prevSample; // pre-emphasis filter carry for the next frame

  const _FrameResult({
    required this.frequency,
    required this.confidence,
    required this.prevSample,
  });
}
