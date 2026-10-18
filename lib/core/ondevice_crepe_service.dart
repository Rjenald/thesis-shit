/// Real-time pitch detection using the actual CREPE model running ON THE
/// DEVICE — no server, no network. Loads assets/models/huni_crepe.tflite
/// (standard CREPE architecture: 1024-sample @16kHz input, 360-bin pitch
/// salience output) and runs inference locally via tflite_flutter.
///
/// Preprocessing matches what CREPE was actually trained on — per-frame
/// DC-offset removal and z-score normalization, nothing else — plus an
/// RMS-energy VAD gate that skips inference entirely on near-silent frames
/// (saves battery and avoids feeding the model noise). An earlier version
/// of this also applied a pre-emphasis high-pass filter before those steps;
/// that's a deviation from CREPE's real preprocessing, and on real singing
/// (as opposed to a clean test tone) it measurably suppressed confidence —
/// especially on lower notes, since pre-emphasis specifically attenuates
/// low frequencies — enough that real voiced audio never crossed the
/// confidence threshold. Removed.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  static const _confidenceThreshold = kDefaultPitchConfidenceThreshold;
  // RMS floor below which a frame is treated as silence/noise and skipped.
  static const _vadRmsFloor = 0.01;

  // rootBundle.load() re-reads the asset (APK/platform-channel round trip)
  // every single call — Flutter's asset bundle does NOT cache raw ByteData
  // on its own. Every OnDeviceCrepeService instance (one per recording's
  // offline pass, plus the live-mic one in karaoke mode) was paying that
  // read again. Caching the decoded bytes once, process-wide, lets every
  // instance skip straight to InterpreterCreate — each still builds its own
  // independent Interpreter, so there's no cross-instance sharing/concurrency
  // risk, just a skipped I/O read.
  static Uint8List? _cachedModelBytes;
  static Future<Uint8List>? _modelBytesLoading;

  static Future<Uint8List> _loadModelBytes() {
    final cached = _cachedModelBytes;
    if (cached != null) return Future.value(cached);
    return _modelBytesLoading ??= () async {
      final data = await rootBundle.load(_modelAsset);
      final bytes = data.buffer.asUint8List();
      _cachedModelBytes = bytes;
      return bytes;
    }();
  }

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
      final buffer = await _loadModelBytes();
      final options = InterpreterOptions()..threads = 4;
      _interpreter = Interpreter.fromBuffer(buffer, options: options);
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

    final frame = _computeFrame(intFrame);

    // frequency <= 0 covers the VAD-gated/error case; confidence below
    // threshold covers "the model ran but isn't sure" — _computeFrame
    // always decodes a frequency once it runs the model, regardless of
    // confidence, so this needs to check both explicitly.
    if (frame.frequency <= 0 || frame.confidence < _confidenceThreshold) {
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
  /// and the offline batch pass ([analyzeOffline]): DC removal + z-score
  /// normalization (exactly CREPE's expected input, nothing more), VAD
  /// gate, interpreter inference, and sub-bin peak decode.
  _FrameResult _computeFrame(List<int> intFrame) {
    // int16 -> float32 [-1, 1], DC removal, then z-score normalization.
    final floats = Float64List(_frameSize);
    double mean = 0;
    for (var i = 0; i < _frameSize; i++) {
      final sample = intFrame[i] / 32768.0;
      floats[i] = sample;
      mean += sample;
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
      return const _FrameResult(frequency: 0, confidence: 0);
    }

    final std = rms.clamp(1e-8, double.infinity);
    final input = [List<double>.generate(_frameSize, (i) => floats[i] / std)];
    final output = [List<double>.filled(360, 0.0)];

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint('CREPE inference error: $e');
      return const _FrameResult(frequency: 0, confidence: 0);
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

    // Decode the frequency regardless of confidence — confidence alone
    // signals reliability (see [PitchFrame.confidence]); callers that need
    // a hard cutoff apply it explicitly (e.g. [_runInference] for the live
    // UI). Keeping this unconditional is also what makes it possible to
    // inspect what the model actually saw on a low-confidence frame instead
    // of just a zeroed-out "no signal", which is what let the diagnostics
    // below catch a real preprocessing bug instead of guessing at
    // threshold numbers.
    //
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
    );
  }

  /// Loads the CREPE interpreter if it isn't already loaded. Safe to call
  /// early (e.g. as soon as a recording screen opens) to warm the model
  /// before [analyzeOffline] actually needs it — asset loading and
  /// `allocateTensors()` are the fixed cost paid on first use, so doing it
  /// ahead of time keeps it off the critical path after the user hits stop.
  Future<void> preload() async {
    if (_interpreter != null) return;
    final buffer = await _loadModelBytes();
    final options = InterpreterOptions()..threads = 4;
    _interpreter = Interpreter.fromBuffer(buffer, options: options);
    _interpreter!.allocateTensors();
  }

  /// Runs CREPE over an entire pre-recorded PCM16 buffer instead of live mic
  /// input — for post-recording analysis (e.g. a full-recording summary)
  /// rather than real-time feedback. Loads its own interpreter on first call
  /// if [preload] wasn't already called; call [dispose] afterwards to
  /// release it.
  Future<List<PitchFrame>> analyzeOffline(
    List<int> pcm16Samples, {
    int hopMs = 100,
  }) async {
    await preload();

    final hopSamples = math.max(1, (_sampleRate * hopMs / 1000).round());
    final frames = <PitchFrame>[];

    for (
      var start = 0;
      start + _frameSize <= pcm16Samples.length;
      start += hopSamples
    ) {
      final frame = pcm16Samples.sublist(start, start + _frameSize);
      final result = _computeFrame(frame);
      frames.add(PitchFrame(
        timeMs: (start / _sampleRate * 1000).round(),
        frequency: result.frequency,
        confidence: result.confidence,
      ));

      // Each interpreter.run() call above is a synchronous blocking FFI
      // call with no natural await point — back-to-back over hundreds of
      // hops that would freeze the UI isolate for the whole batch (no
      // frame rendering, no spinner animation) and starve any concurrently
      // running Future (e.g. Whisper transcription) of event-loop turns.
      // Yielding after every hop keeps the app responsive and lets other
      // work actually interleave, at negligible cost next to inference time.
      await Future<void>.delayed(Duration.zero);
    }

    _logOfflineDiagnostics(frames);
    return frames;
  }

  /// Temporary diagnostic: when every syllable in a real recording comes
  /// back with no detected pitch, this pinpoints WHERE in the pipeline it's
  /// being lost — near-silent audio never reaching the model (VAD gate) vs.
  /// the model running but never clearing the confidence bar — instead of
  /// guessing at threshold changes blind. Safe to remove once resolved.
  void _logOfflineDiagnostics(List<PitchFrame> frames) {
    if (frames.isEmpty) {
      debugPrint('[CREPE offline] no frames produced (recording too short?)');
      return;
    }
    // confidence == 0.0 means the VAD gate skipped inference entirely for
    // that hop (or, rarely, the interpreter threw) — it never got a real
    // peak-activation reading. Anything else ran through the model.
    final vadGated = frames.where((f) => f.confidence == 0.0).length;
    final ranInference = frames.where((f) => f.confidence > 0.0).toList();
    final belowThreshold =
        ranInference.where((f) => f.confidence < _confidenceThreshold).length;
    final aboveThreshold = ranInference.length - belowThreshold;
    final maxConfidence = ranInference.isEmpty
        ? 0.0
        : ranInference.map((f) => f.confidence).reduce(math.max);
    final avgConfidence = ranInference.isEmpty
        ? 0.0
        : ranInference.map((f) => f.confidence).reduce((a, b) => a + b) /
            ranInference.length;
    debugPrint(
      '[CREPE offline] ${frames.length} hops total — '
      '$vadGated silence-gated (never reached the model), '
      '${ranInference.length} reached the model '
      '($belowThreshold below ${_confidenceThreshold.toStringAsFixed(2)} '
      'confidence, $aboveThreshold above). '
      'maxConfidence=${maxConfidence.toStringAsFixed(3)} '
      'avgConfidence=${avgConfidence.toStringAsFixed(3)}',
    );

    // Sanity-check plausibility of what's being discarded: is the model
    // landing on musically reasonable frequencies (~80–500 Hz vocal range)
    // just without enough confidence, or is it decoding noise? Shows the
    // 8 highest-confidence discarded frames — the ones closest to actually
    // being accepted.
    if (ranInference.isNotEmpty) {
      final sample = ranInference.toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final preview = sample.take(8).map((f) {
        final note = f.frequency > 0 ? hzToNoteName(f.frequency) : '--';
        return '${f.timeMs}ms:${f.frequency.toStringAsFixed(1)}Hz'
            '($note,conf=${f.confidence.toStringAsFixed(3)})';
      }).join('  ');
      debugPrint('[CREPE offline] top discarded frames: $preview');
    }
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

  const _FrameResult({
    required this.frequency,
    required this.confidence,
  });
}
