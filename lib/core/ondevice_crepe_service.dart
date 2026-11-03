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
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'note_utils.dart';
import 'pitch_detection_service.dart';

/// A time range of a recording worth running the pitch model over, in
/// milliseconds relative to the start of that recording.
///
/// Exists so a caller that already knows which parts of a take anything
/// will read — karaoke knows its ground-truth syllable windows, freestyle
/// knows its recognized word windows — can say so, instead of paying for
/// model time on audio whose frames get filtered out immediately after.
class AnalysisWindow {
  final int startMs;
  final int endMs;
  const AnalysisWindow(this.startMs, this.endMs);

  /// Widened by [ms] on both sides, floored at zero. Used to cover the
  /// nearest-frame tolerance the segment builders fall back on, so
  /// windowing can't take away a frame they would have used.
  AnalysisWindow padded(int ms) =>
      AnalysisWindow(startMs - ms < 0 ? 0 : startMs - ms, endMs + ms);

  @override
  String toString() => 'AnalysisWindow($startMs..$endMs)';
}

class OnDeviceCrepeService implements PitchDetectionService {
  static const _modelAsset = 'assets/models/huni_crepe.tflite';
  static const _frameSize = 1024; // CREPE's fixed input width
  static const _activationBins = 360; // CREPE's pitch-bin output width
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

  /// Batch size the input tensor is currently sized for, so [_setBatchSize]
  /// can skip a resize it doesn't need.
  int _currentBatch = 1;

  /// The offline sweep currently running in a worker isolate, if any.
  ///
  /// Held so teardown can wait for it: the worker drives this instance's
  /// interpreter through a raw native address, and closing the
  /// interpreter underneath it would be a use-after-free in C, not a Dart
  /// exception.
  Future<_SweepResult>? _offlineJob;

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
    final buffer = Float32List(_frameSize);
    if (!_preprocessInto(intFrame, 0, buffer, 0)) {
      return const _FrameResult(frequency: 0, confidence: 0);
    }

    final Float32List activations;
    try {
      activations = _infer(buffer, 1);
    } catch (e) {
      debugPrint('CREPE inference error: $e');
      return const _FrameResult(frequency: 0, confidence: 0);
    }
    return _decodeActivation(activations, 0);
  }

  /// CREPE's expected preprocessing for one frame: int16 -> float in
  /// [-1, 1], DC removal, z-score normalization. Writes
  /// [_frameSize] floats into [dest] at [destOffset].
  ///
  /// Returns false when the frame is below the VAD floor, in which case
  /// nothing is written and the caller must skip inference for it — which
  /// is the point: a silent frame costs no model time at all.
  ///
  /// Takes a source offset rather than a pre-sliced frame so the batch
  /// path can read straight out of the recording's PCM without allocating
  /// a 1024-element list per hop.
  /// Static so the offline worker isolate runs this exact code rather
  /// than a copy of it — the claim that moving the sweep off the UI
  /// isolate changes nothing about the result depends on the arithmetic
  /// being literally the same function.
  static bool _preprocessInto(
    List<int> pcm,
    int start,
    Float32List dest,
    int destOffset,
  ) {
    double mean = 0;
    for (var i = 0; i < _frameSize; i++) {
      final sample = pcm[start + i] / 32768.0;
      dest[destOffset + i] = sample;
      mean += sample;
    }
    mean /= _frameSize;

    double sumSquares = 0;
    for (var i = 0; i < _frameSize; i++) {
      final centered = dest[destOffset + i] - mean;
      dest[destOffset + i] = centered;
      sumSquares += centered * centered;
    }
    final rms = math.sqrt(sumSquares / _frameSize);

    // VAD gate: skip inference on near-silent/noise-floor frames entirely.
    if (rms < _vadRmsFloor) return false;

    final std = rms.clamp(1e-8, double.infinity);
    for (var i = 0; i < _frameSize; i++) {
      dest[destOffset + i] = dest[destOffset + i] / std;
    }
    return true;
  }

  /// Runs [batch] frames packed back-to-back in [input] through the model
  /// and returns the raw activations, [batch] * 360 of them.
  ///
  /// The model's input shape signature is [-1, 1024], so the batch
  /// dimension is resizable. Batching is purely a throughput change:
  /// measured against one-frame-per-invoke, the activations come back
  /// bit-identical (max absolute difference 0.0 over 128 frames at every
  /// batch size tried), so no detected pitch can shift.
  ///
  /// Uses the tensors directly instead of `run()` with nested Dart lists,
  /// which converts element by element on every call.
  Float32List _infer(Float32List input, int batch) {
    _setBatchSize(batch);
    _interpreter!.getInputTensor(0).setTo(input);
    _interpreter!.invoke();
    final bytes = _interpreter!.getOutputTensor(0).data;
    return Float32List.view(
        bytes.buffer, bytes.offsetInBytes, batch * _activationBins);
  }

  /// Resizes the input tensor only when the batch size actually changes —
  /// resize plus allocateTensors is not free, and the batch loop would
  /// otherwise pay it on every chunk.
  void _setBatchSize(int batch) {
    if (_currentBatch == batch) return;
    _interpreter!.resizeInputTensor(0, [batch, _frameSize]);
    _interpreter!.allocateTensors();
    _currentBatch = batch;
  }

  /// Standard CREPE decode of one frame's 360 activations, starting at
  /// `frameIndex * 360` in [activations].
  static _FrameResult _decodeActivation(
      Float32List activations, int frameIndex) {
    final base = frameIndex * _activationBins;
    var peakBin = 0;
    var peakVal = activations[base];
    for (var i = 1; i < _activationBins; i++) {
      if (activations[base + i] > peakVal) {
        peakVal = activations[base + i];
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
    final hi = math.min(_activationBins - 1, peakBin + window);
    double weightedBin = 0, weightSum = 0;
    for (var i = lo; i <= hi; i++) {
      weightedBin += i * activations[base + i];
      weightSum += activations[base + i];
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
  /// [windows] restricts analysis to the given time ranges (milliseconds,
  /// relative to the start of [pcm16Samples]). Null analyses everything.
  ///
  /// Restricting is not an approximation. Both consumers of these frames
  /// ([buildSingingSegments], [buildWordNotes]) only ever read frames that
  /// fall inside a syllable's own window, so frames outside every window
  /// were computed and then discarded. Passing the windows in produces the
  /// identical frames where anything reads them, and skips the model
  /// entirely where nothing does.
  ///
  /// [batchSize] frames go through the model per invoke. Measured against
  /// one frame per invoke the activations are bit-identical, so this only
  /// changes throughput.
  Future<List<PitchFrame>> analyzeOffline(
    List<int> pcm16Samples, {
    int hopMs = 100,
    List<AnalysisWindow>? windows,
    int batchSize = 16,
  }) async {
    await preload();

    final hopSamples = math.max(1, (_sampleRate * hopMs / 1000).round());
    final starts = _framePositions(
      pcm16Samples.length,
      hopSamples,
      windows,
    );

    // Int16List rather than whatever List<int> the caller had: it is what
    // crosses to the worker, and a plain List<int> would be copied element
    // by element as boxed integers.
    final samples = pcm16Samples is Int16List
        ? pcm16Samples
        : Int16List.fromList(pcm16Samples);

    final sw = Stopwatch()..start();

    // The sweep runs in a worker isolate. invoke() is a blocking FFI call
    // with no await point inside it, so on the UI isolate every batch
    // froze the interface for as long as the batch took — a three-minute
    // freestyle take is ~3600 hops, which is tens of seconds of a
    // stuttering "Analyzing…" screen. Yielding between batches did not
    // help much: the yield is between the freezes, not during them.
    //
    // The interpreter is handed over by native address, not copied: the
    // model is 44 MB and copying it per analysis would spike memory on
    // exactly the low-end phones this is meant to help. That makes the
    // native object shared, so nothing else may touch it while the worker
    // runs — [dispose] waits on [_offlineJob] for that reason, and the
    // live-mic path uses its own OnDeviceCrepeService instance.
    final address = _interpreter!.address;
    final job = Isolate.run(() => _sweepOffline(
          address,
          samples,
          starts,
          batchSize,
        ));
    _offlineJob = job;
    final _SweepResult swept;
    try {
      swept = await job;
    } finally {
      _offlineJob = null;
    }
    // The worker resized the shared interpreter's input tensor, so the
    // live path's idea of the current batch size is stale.
    _currentBatch = swept.lastBatch;

    final frames = <PitchFrame>[
      for (var i = 0; i < swept.timesMs.length; i++)
        PitchFrame(
          timeMs: swept.timesMs[i],
          frequency: swept.frequencies[i],
          confidence: swept.confidences[i],
        ),
    ];

    // Frames come back in VAD/batch order, not time order; downstream
    // window filters don't care but the gap detection in
    // buildPitchOnlyNotes does, and so does anything reading this as a
    // timeline.
    frames.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    debugPrint('[CREPE offline] ${sw.elapsedMilliseconds}ms for '
        '${starts.length} hops '
        '(${swept.inferences} inferred, ${swept.gated} silent-skipped, '
        'batch=$batchSize'
        '${windows == null ? '' : ', ${windows.length} windows'})'
        '${swept.inferences == 0 ? '' : ' — '
            '${(sw.elapsedMilliseconds / swept.inferences).toStringAsFixed(1)}'
            'ms per inference'}');
    _logOfflineDiagnostics(frames);
    return frames;
  }

  /// Which frame offsets a run would analyse. Exposed because the whole
  /// claim of windowing — that it produces the same frames a full sweep
  /// would, just without the ones nothing reads — lives in this function.
  @visibleForTesting
  static List<int> framePositionsForTest(
    int sampleCount,
    int hopSamples,
    List<AnalysisWindow>? windows,
  ) =>
      _framePositions(sampleCount, hopSamples, windows);

  /// Frame start offsets (in samples) to analyse: every hop across the
  /// whole buffer, or only the hops inside [windows].
  ///
  /// Overlapping windows are merged first, so a frame is never analysed
  /// twice and the result has no duplicate timestamps.
  static List<int> _framePositions(
    int sampleCount,
    int hopSamples,
    List<AnalysisWindow>? windows,
  ) {
    final last = sampleCount - _frameSize;
    if (last < 0) return const [];

    if (windows == null || windows.isEmpty) {
      return [for (var s = 0; s <= last; s += hopSamples) s];
    }

    final ranges = windows
        .map((w) => AnalysisWindow(
              math.max(0, w.startMs),
              math.max(0, w.endMs),
            ))
        .where((w) => w.endMs >= w.startMs)
        .toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final merged = <AnalysisWindow>[];
    for (final w in ranges) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null && w.startMs <= last.endMs) {
        merged[merged.length - 1] =
            AnalysisWindow(last.startMs, math.max(last.endMs, w.endMs));
      } else {
        merged.add(w);
      }
    }

    final starts = <int>[];
    for (final w in merged) {
      // Snap to the hop grid so the positions are the same ones a full
      // sweep would have produced — otherwise windowed and full runs would
      // disagree on timestamps for no reason.
      final firstSample = (w.startMs * _sampleRate / 1000).floor();
      final lastSample = (w.endMs * _sampleRate / 1000).ceil();
      var s = (firstSample ~/ hopSamples) * hopSamples;
      if (s < 0) s = 0;
      for (; s <= math.min(lastSample, last); s += hopSamples) {
        if (starts.isEmpty || starts.last != s) starts.add(s);
      }
    }
    return starts;
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
    await _closeInterpreter();
    _pcmBuffer.clear();
  }

  /// Closes the interpreter, but not while a worker isolate is still
  /// using it. The worker holds a raw native address, so freeing it
  /// mid-sweep crashes the process rather than throwing.
  Future<void> _closeInterpreter() async {
    final job = _offlineJob;
    if (job != null) {
      try {
        await job;
      } catch (_) {
        // The sweep's own failure is reported by analyzeOffline; here the
        // only thing that matters is that the worker has finished.
      }
    }
    _interpreter?.close();
    _interpreter = null;
  }

  @override
  void dispose() {
    _isRunning = false;
    _audioSub?.cancel();
    _audioSub = null;
    // Not awaited — dispose() is synchronous by contract — but the close
    // itself still waits for any running sweep before freeing the model.
    _closeInterpreter().ignore();
    _resultController?.close();
    _resultController = null;
    _bytesController.close();
    _recorder.stop().ignore();
  }
}

/// What one offline sweep produced, in a shape that can cross an isolate
/// cheaply: parallel typed lists rather than a list of objects.
class _SweepResult {
  final Int32List timesMs;
  final Float64List frequencies;
  final Float64List confidences;

  /// How many frames reached the model, and how many the VAD gate skipped
  /// — reported in the timing log, which is how a regression in the gate
  /// would be noticed.
  final int inferences;
  final int gated;

  /// The batch size the shared interpreter's input tensor was left at, so
  /// the owning isolate can resync rather than assume.
  final int lastBatch;

  const _SweepResult({
    required this.timesMs,
    required this.frequencies,
    required this.confidences,
    required this.inferences,
    required this.gated,
    required this.lastBatch,
  });
}

/// The batch CREPE sweep, as it runs inside the worker isolate.
///
/// Top-level because that is what `Isolate.run` can execute, and it only
/// touches what it is handed plus `OnDeviceCrepeService`'s static frame
/// maths — the preprocessing and decode are the very same functions the
/// live path calls, so moving the loop here cannot change a result.
///
/// [interpreterAddress] is the native handle of an interpreter owned by
/// the calling isolate. Nothing else may use it while this runs.
_SweepResult _sweepOffline(
  int interpreterAddress,
  Int16List samples,
  List<int> starts,
  int batchSize,
) {
  final interpreter = Interpreter.fromAddress(interpreterAddress);

  final timesMs = <int>[];
  final frequencies = <double>[];
  final confidences = <double>[];

  final batch = Float32List(batchSize * OnDeviceCrepeService._frameSize);
  // Starts whose frame cleared the VAD gate and so still needs the model.
  final pending = <int>[];
  var gated = 0;
  var inferences = 0;
  var currentBatch = -1;

  void record(int start, double frequency, double confidence) {
    timesMs.add(
        (start / OnDeviceCrepeService._sampleRate * 1000).round());
    frequencies.add(frequency);
    confidences.add(confidence);
  }

  void runPending() {
    if (pending.isEmpty) return;
    final count = pending.length;
    try {
      if (currentBatch != count) {
        interpreter.resizeInputTensor(
            0, [count, OnDeviceCrepeService._frameSize]);
        interpreter.allocateTensors();
        currentBatch = count;
      }
      interpreter.getInputTensor(0).setTo(
            count == batchSize
                ? batch
                : Float32List.view(
                    batch.buffer, 0, count * OnDeviceCrepeService._frameSize),
          );
      interpreter.invoke();
      final bytes = interpreter.getOutputTensor(0).data;
      final activations = Float32List.view(bytes.buffer, bytes.offsetInBytes,
          count * OnDeviceCrepeService._activationBins);
      for (var i = 0; i < count; i++) {
        final r = OnDeviceCrepeService._decodeActivation(
            activations, i);
        record(pending[i], r.frequency, r.confidence);
      }
      inferences += count;
    } catch (e) {
      // A failed batch becomes silence for those hops rather than losing
      // the whole sweep — the same behaviour as before this moved here.
      debugPrint('CREPE batch inference error: $e');
      for (final start in pending) {
        record(start, 0, 0);
      }
    }
    pending.clear();
  }

  for (final start in starts) {
    final ok = OnDeviceCrepeService._preprocessInto(
      samples,
      start,
      batch,
      pending.length * OnDeviceCrepeService._frameSize,
    );
    if (!ok) {
      // Silence never reaches the model, so it costs nothing.
      gated++;
      record(start, 0, 0);
      continue;
    }
    pending.add(start);
    if (pending.length == batchSize) runPending();
  }
  runPending();

  return _SweepResult(
    timesMs: Int32List.fromList(timesMs),
    frequencies: Float64List.fromList(frequencies),
    confidences: Float64List.fromList(confidences),
    inferences: inferences,
    gated: gated,
    lastBatch: currentBatch,
  );
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
