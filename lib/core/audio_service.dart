/// AudioService — streams mic PCM to the CREPE backend WebSocket and
/// emits NoteResult events.
///
/// Primary:  CREPE server via WebSocket (highest accuracy, ~±5 cents).
/// Fallback: On-device YIN pitch detector  (works without any server, ~±10 cents).
///
/// Accuracy improvements vs. original:
///  • Fallback timer raised to 1 500 ms — gives slower networks more time.
///  • CREPE results below 0.55 confidence are silently dropped.
///  • Emissions are rate-limited to at most one per 80 ms (≤12 Hz) so the UI
///    is not flooded with redundant readings.
///  • Local detector now uses Hanning window + stricter threshold + median
///    filter (see LocalPitchDetector for details).
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

  // ── Tuning constants ────────────────────────────────────────────────────────

  /// Time to wait for the first WebSocket message before falling back to
  /// local detection. Raised from 800 ms → 1 500 ms for slow connections.
  static const Duration _wsFallbackDelay = Duration(milliseconds: 1500);

  /// Minimum CREPE confidence to accept a result.
  /// Readings below this are noise / vowel transitions — discard them.
  static const double _minConfidence = 0.55;

  /// Minimum time between emitted results (rate limiter).
  /// Prevents flooding the UI at 100+ Hz; 80 ms gives ~12 Hz update rate.
  static const Duration _minEmitInterval = Duration(milliseconds: 80);

  // ── Internal state ──────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  WebSocketChannel? _ws;

  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<dynamic>? _wsSub;

  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  bool _isRunning = false;
  bool _disposed = false;

  bool _wsReceived = false;
  bool _useLocal = false;
  Timer? _fallbackTimer;

  final LocalPitchDetector _localDetector = LocalPitchDetector();
  double? _targetFreq;

  // Rate-limiter state
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Request mic permission, connect to CREPE WebSocket, start streaming.
  /// Returns false only if microphone permission is denied.
  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    _targetFreq = targetFreq;
    _wsReceived = false;
    _useLocal = false;
    _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
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
          _wsReceived = true;
          _fallbackTimer?.cancel();
          _fallbackTimer = null;

          try {
            final data =
                json.decode(message as String) as Map<String, dynamic>;
            final freq = (data['frequency'] as num).toDouble();
            final conf = (data['confidence'] as num?)?.toDouble() ?? 1.0;

            // Gate: ignore low-confidence readings (noise / transitions)
            if (conf < _minConfidence) {
              _emitIfReady(null);
              return;
            }

            if (freq > 0) {
              _emitIfReady(analyzeFrequency(
                freq,
                targetFreq: targetFreq,
                confidence: conf,
              ));
            } else {
              _emitIfReady(null);
            }
          } catch (_) {
            _emitIfReady(null);
          }
        },
        onError: (_) => _activateLocalFallback(),
        onDone: () => _activateLocalFallback(),
        cancelOnError: true,
      );

      // Ping the sink to detect immediate connection refusal
      try {
        _ws!.sink.add('ping');
      } catch (_) {
        _activateLocalFallback();
      }
    } catch (_) {
      _useLocal = true;
    }

    // ── 3. Fallback timer ────────────────────────────────────────────────────
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
          try {
            _ws?.sink.add(Uint8List.fromList(bytes));
          } catch (_) {
            _activateLocalFallback();
          }
        }
      },
      onError: (_) {
        if (!_disposed) _emitIfReady(null);
      },
    );

    return true;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Emit a result only if the rate-limiter allows it.
  void _emitIfReady(NoteResult? result) {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastEmit) < _minEmitInterval) return; // throttle
    _lastEmit = now;
    _resultController.add(result);
  }

  /// Switch to on-device YIN (idempotent — safe to call multiple times).
  void _activateLocalFallback() {
    if (_useLocal || _disposed) return;
    _useLocal = true;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _localDetector.reset();
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

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
