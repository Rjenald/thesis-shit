library;

import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import 'crepe_detector.dart';   // ← new
import 'note_utils.dart';

Uint8List _toUint8List(List<int> list) {
  if (list is Uint8List) return list;
  return Uint8List.fromList(list);
}

class AudioService {
  static const int _sampleRate = 44100;

  final _recorder = AudioRecorder();
  final _detector = CrepeDetector();   // ← swapped to CREPE

  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  StreamSubscription<List<int>>? _audioSub;
  bool _isRunning = false;
  bool _disposed = false;
  bool _modelReady = false;

  bool get isRunning => _isRunning;

  /// Call this once at app startup (e.g. in initState of your first screen)
  Future<void> initialize() async {
    await _detector.load();
    _modelReady = _detector.isLoaded;
  }

  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;
    if (!_modelReady) await initialize();

    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
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

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    _detector.reset();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isRunning = false;
    final sub = _audioSub;
    _audioSub = null;
    sub?.cancel();
    _resultController.close();
    _detector.dispose();
    _recorder.stop().then((_) => _recorder.dispose()).ignore();
  }
}