/// AudioService — streams mic PCM to the CREPE backend WebSocket and
/// emits NoteResult events.
///
/// Primary:  CREPE server via WebSocket (highest accuracy).
/// Fallback: On-device YIN pitch detector (works without any server).
///
/// The fallback activates automatically if the WebSocket does not send its
/// first message within [_wsFallbackDelay].  Once local mode is active it
/// stays active for the duration of the session.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'local_pitch_detector.dart';
import 'note_utils.dart';
import 'pitch_server_config.dart';

class AudioService {
  static const int _sampleRate = 44100;

  // How long to wait for the first WebSocket message before giving up
  static const Duration _wsFallbackDelay = Duration(milliseconds: 800);

  final _recorder = AudioRecorder();
  WebSocketChannel? _ws;

  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  bool _isRunning = false;
  bool _disposed = false;

  // ── WebSocket health tracking ───────────────────────────────────────────────
  bool _wsReceived = false; // true once the first WS message arrives
  bool _useLocal = false;   // true when falling back to on-device detection
  Timer? _fallbackTimer;

  // ── Local (on-device) pitch detection ──────────────────────────────────────
  final LocalPitchDetector _localDetector = LocalPitchDetector();
  double? _targetFreq; // stored so local mode can use it too

  bool get isRunning => _isRunning;

  /// Request mic permission, connect to CREPE WebSocket, start streaming.
  /// Returns false only if microphone permission is denied.
  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    _targetFreq = targetFreq;
    _wsReceived = false;
    _useLocal = false;
    _localDetector.reset();

    // ── 1. Mic permission ───────────────────────────────────────────────────
    final status = await Permission.microphone.request();
    if (!status.isGranted || _disposed) return false;

    // ── 2. Try to connect to CREPE WebSocket ────────────────────────────────
    try {
      _ws = WebSocketChannel.connect(Uri.parse(PitchServerConfig.wsUrl));

      _wsSub = _ws!.stream.listen(
        (message) {
          if (_disposed) return;
          _wsReceived = true; // server is alive — cancel fallback timer
          _fallbackTimer?.cancel();
          _fallbackTimer = null;

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
          // WebSocket error → switch to local immediately
          _activateLocalFallback();
        },
        onDone: () {
          // Server closed → switch to local
          _activateLocalFallback();
        },
        cancelOnError: true,
      );

      // Ping the sink to detect immediate connection refusal
      try {
        _ws!.sink.add('ping');
      } catch (_) {
        _activateLocalFallback();
      }
    } catch (_) {
      // Could not even create the WebSocket → use local immediately
      _useLocal = true;
    }

    // ── 3. Fallback timer — give the server 3 s to respond ─────────────────
    if (!_useLocal) {
      _fallbackTimer = Timer(_wsFallbackDelay, () {
        if (!_wsReceived && !_disposed) _activateLocalFallback();
      });
    }

    // ── 4. Start microphone PCM stream ──────────────────────────────────────
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

    // ── 5. Route PCM bytes → WebSocket OR local detector ────────────────────
    _audioSub = stream.listen(
      (bytes) {
        if (_disposed) return;

        if (_useLocal) {
          // ── On-device YIN pitch detection ───────────────────────────────
          final hz = _localDetector.process(bytes);
          if (hz == null) return; // buffer not full yet
          if (!_disposed) {
            if (hz > 0) {
              _resultController.add(analyzeFrequency(
                hz,
                targetFreq: _targetFreq,
                confidence: 1.0, // local detector has no confidence score
              ));
            } else {
              _resultController.add(null); // silence
            }
          }
        } else {
          // ── Stream to CREPE server ───────────────────────────────────────
          try {
            _ws?.sink.add(Uint8List.fromList(bytes));
          } catch (_) {
            _activateLocalFallback();
          }
        }
      },
      onError: (_) {
        if (!_disposed) _resultController.add(null);
      },
    );

    return true;
  }

  /// Switch to on-device detection (idempotent — safe to call multiple times).
  void _activateLocalFallback() {
    if (_useLocal || _disposed) return;
    _useLocal = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _localDetector.reset();
  }

  /// Stop recording and close WebSocket. Safe to call multiple times.
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _useLocal = false;
    _wsReceived = false;
    _localDetector.reset();
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
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

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
