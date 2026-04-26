/// AudioService — streams mic PCM to the CREPE backend WebSocket and
/// emits NoteResult events. All pitch detection runs server-side (full model).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'note_utils.dart';
import 'pitch_server_config.dart';

class AudioService {
  static const int _sampleRate = 44100;

  final _recorder = AudioRecorder();
  WebSocketChannel? _ws;

  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  bool _isRunning = false;
  bool _disposed = false;

  bool get isRunning => _isRunning;

  /// Request mic permission, connect to CREPE WebSocket, start streaming.
  /// Returns false if permission denied or connection failed.
  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    // ── 1. Mic permission ───────────────────────────────────────────────────
    final status = await Permission.microphone.request();
    if (!status.isGranted || _disposed) return false;

    // ── 2. Connect to CREPE WebSocket ───────────────────────────────────────
    try {
      _ws = WebSocketChannel.connect(Uri.parse(PitchServerConfig.wsUrl));

      _wsSub = _ws!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final data =
                json.decode(message as String) as Map<String, dynamic>;
            final freq = (data['frequency'] as num).toDouble();
            final conf = (data['confidence'] as num?)?.toDouble() ?? 1.0;
            if (freq > 0) {
              _resultController.add(analyzeFrequency(
                freq,
                targetFreq: targetFreq,
                confidence: conf,
              ));
            } else {
              _resultController.add(null);
            }
          } catch (_) {
            _resultController.add(null);
          }
        },
        onError: (_) {
          if (!_disposed) _resultController.add(null);
        },
      );
    } catch (_) {
      return false;
    }

    // ── 3. Start microphone PCM stream ──────────────────────────────────────
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );

    if (_disposed) {
      await _ws?.sink.close();
      _ws = null;
      return false;
    }

    final stream = await _recorder.startStream(config);

    if (_disposed) {
      await _recorder.stop();
      await _ws?.sink.close();
      _ws = null;
      return false;
    }

    _isRunning = true;

    // ── 4. Forward PCM bytes → WebSocket ────────────────────────────────────
    _audioSub = stream.listen(
      (bytes) {
        if (_disposed) return;
        try {
          _ws?.sink.add(Uint8List.fromList(bytes));
        } catch (_) {}
      },
      onError: (_) {
        if (!_disposed) _resultController.add(null);
      },
    );

    return true;
  }

  /// Stop recording and close WebSocket. Safe to call multiple times.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    await _wsSub?.cancel();
    _wsSub = null;
    await _ws?.sink.close();
    _ws = null;
  }

  /// Dispose the service. Safe to call even if stop() was not called.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isRunning = false;

    final sub = _audioSub;
    _audioSub = null;
    sub?.cancel();

    _wsSub?.cancel();
    _wsSub = null;

    _resultController.close();

    _recorder.stop().then((_) => _recorder.dispose()).ignore();
    try {
      _ws?.sink.close();
    } catch (_) {}
    _ws = null;
  }
}
