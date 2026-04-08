/// Manages the microphone recording session and feeds PCM data to
/// the PitchDetector. Emits NoteResult events via a stream.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'pitch_detector.dart';
import 'note_utils.dart';

// The `record` package stream emits `List<int>`. This helper converts to
// Uint8List without an extra copy when the underlying list is already one.
Uint8List _toUint8List(List<int> list) {
  if (list is Uint8List) return list;
  return Uint8List.fromList(list);
}

class AudioService {
  static const int _sampleRate = 44100;

  final _recorder = AudioRecorder();
  final _detector = PitchDetector(
    bufferSize: 4096,
    sampleRate: _sampleRate,
    threshold: 0.12,
    minFrequency: 80.0,
    maxFrequency: 1100.0,
  );

  // Public stream of detected note results (null = no signal)
  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  StreamSubscription<List<int>>? _audioSub;
  bool _isRunning = false;
  bool _disposed = false;

  bool get isRunning => _isRunning;

  /// Request microphone permission and start streaming audio.
  /// Returns false if permission was denied or the service was disposed.
  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    // Guard: widget may have been disposed while the permission dialog was open
    if (_disposed) return false;

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );

    _detector.reset();
    final stream = await _recorder.startStream(config);

    // Guard: disposed while awaiting startStream
    if (_disposed) {
      await _recorder.stop();
      return false;
    }

    _isRunning = true;

    _audioSub = stream.listen(
      (bytes) {
        if (_disposed) return;
        final freq = _detector.addPcmBytes(_toUint8List(bytes));
        if (freq != null) {
          _resultController.add(analyzeFrequency(freq, targetFreq: targetFreq));
        } else {
          _resultController.add(null);
        }
      },
      onError: (e) {
        if (!_disposed) _resultController.addError(e);
      },
    );

    return true;
  }

  /// Stop recording and release the microphone.
  /// Safe to call multiple times.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    _detector.reset();
  }

  /// Dispose the service. Safe to call even if stop() has not been called.
  /// Properly sequences stop → dispose to avoid the recorder race condition.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isRunning = false;

    // Cancel the subscription synchronously so no more events are emitted
    final sub = _audioSub;
    _audioSub = null;
    sub?.cancel();

    _resultController.close();

    // Sequence stop() before recorder dispose — cannot await in dispose(),
    // so chain via .then(). The recorder.stop() is a no-op if not recording.
    _recorder.stop().then((_) => _recorder.dispose()).ignore();
  }
}
