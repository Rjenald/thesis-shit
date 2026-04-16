/// AudioService — hybrid pitch detection + optional WAV recording.
///
/// 1. Tries to connect to the Python CREPE WebSocket server.
/// 2. If unreachable, falls back to on-device YIN pitch detector.
/// 3. Optionally buffers raw PCM bytes so they can be saved as a WAV file.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'note_utils.dart';
import 'pitch_detector.dart';
import 'pitch_server_config.dart';

Uint8List _toUint8List(List<int> list) {
  if (list is Uint8List) return list;
  return Uint8List.fromList(list);
}

class AudioService {
  static const int _sampleRate = 44100;

  final _recorder = AudioRecorder();

  // ── On-device YIN fallback ────────────────────────────────────────────────
  final _yin = PitchDetector(
    bufferSize: 4096,
    sampleRate: _sampleRate,
    threshold: 0.12,
    minFrequency: 80.0,
    maxFrequency: 1100.0,
  );

  // ── WebSocket (CREPE server) ───────────────────────────────────────────────
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  bool _usingServer = false;

  // ── Shared ────────────────────────────────────────────────────────────────
  final _resultController = StreamController<NoteResult?>.broadcast();
  Stream<NoteResult?> get results => _resultController.stream;

  StreamSubscription<List<int>>? _audioSub;
  bool _isRunning = false;
  bool _disposed = false;

  // ── PCM recording buffer ──────────────────────────────────────────────────
  List<int>? _pcmBuffer;

  bool get isRunning => _isRunning;
  bool get isUsingServer => _usingServer;

  /// Call this BEFORE start() to enable WAV saving for this session.
  void enableSaving() {
    _pcmBuffer = [];
  }

  /// Pre-warm: try to connect to the server in the background.
  Future<void> initialize() async {
    await _tryConnectServer();
  }

  /// Try WebSocket connection — if it fails within 2 s, mark server unavailable.
  Future<bool> _tryConnectServer() async {
    WebSocketChannel? ws;
    try {
      ws = WebSocketChannel.connect(Uri.parse(PitchServerConfig.wsUrl));
      await ws.ready.timeout(const Duration(seconds: 2));
      _ws = ws;
      _usingServer = true;
      return true;
    } catch (_) {
      try { ws?.sink.close(); } catch (_) {}
      _usingServer = false;
      return false;
    }
  }

  Future<bool> start({double? targetFreq}) async {
    if (_disposed || _isRunning) return _isRunning;

    // ── 1. Microphone permission ──────────────────────────────────────────────
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    if (_disposed) return false;

    // ── 2. Try CREPE server; fall back to YIN ────────────────────────────────
    if (_ws == null) {
      await _tryConnectServer();
    }

    if (_usingServer && _ws != null) {
      _wsSub = _ws!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            final freq = (data['frequency'] as num).toDouble();
            final conf = (data['confidence'] as num).toDouble();
            if (freq > 0 && conf >= 0.5) {
              _resultController.add(analyzeFrequency(freq, targetFreq: targetFreq));
            } else {
              _resultController.add(null);
            }
          } catch (_) {
            _resultController.add(null);
          }
        },
        onError: (_) {
          _usingServer = false;
          _ws = null;
        },
      );
    } else {
      _yin.reset();
    }

    // ── 3. Start microphone stream ────────────────────────────────────────────
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );

    final stream = await _recorder.startStream(config);
    if (_disposed) {
      await _recorder.stop();
      return false;
    }

    _isRunning = true;

    _audioSub = stream.listen(
      (bytes) {
        if (_disposed) return;
        final raw = _toUint8List(bytes);

        // Buffer bytes for WAV saving if enabled
        _pcmBuffer?.addAll(raw);

        if (_usingServer && _ws != null) {
          try { _ws!.sink.add(raw); } catch (_) {}
        } else {
          final freq = _yin.addPcmBytes(raw);
          if (freq != null) {
            _resultController.add(analyzeFrequency(freq, targetFreq: targetFreq));
          } else {
            _resultController.add(null);
          }
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
    _yin.reset();
    await _wsSub?.cancel();
    _wsSub = null;
    if (_usingServer) {
      await _ws?.sink.close();
      _ws = null;
      _usingServer = false;
    }
  }

  /// Save buffered audio as a WAV file. Call after stop().
  /// Returns the saved file path, or null if nothing was recorded.
  Future<String?> saveRecording(String label) async {
    final buf = _pcmBuffer;
    _pcmBuffer = null;
    if (buf == null || buf.isEmpty) return null;

    try {
      final wav = _buildWav(buf);

      // Get writable directory
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final folder = Directory('${dir!.path}/HUNI_Recordings');
      if (!await folder.exists()) await folder.create(recursive: true);

      final path = '${folder.path}/$label.wav';
      await File(path).writeAsBytes(wav);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Build a standard WAV file from raw 16-bit PCM bytes (mono, 44100 Hz).
  Uint8List _buildWav(List<int> pcm) {
    final dataSize = pcm.length;
    final header = ByteData(44);

    void setStr(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    setStr(0, 'RIFF');
    header.setUint32(4, 36 + dataSize, Endian.little);
    setStr(8, 'WAVE');
    setStr(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);      // PCM chunk size
    header.setUint16(20, 1, Endian.little);        // PCM format
    header.setUint16(22, 1, Endian.little);        // mono
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little); // byteRate
    header.setUint16(32, 2, Endian.little);        // blockAlign
    header.setUint16(34, 16, Endian.little);       // bitsPerSample
    setStr(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, wav.length, pcm);
    return wav;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _isRunning = false;
    _pcmBuffer = null;
    final sub = _audioSub;
    _audioSub = null;
    sub?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _resultController.close();
    _recorder.stop().then((_) => _recorder.dispose()).ignore();
  }
}
