/// Real-time pitch detection via the real CREPE model, running on the
/// Python backend (backend/crepe_server.py) instead of locally.
///
/// Streams raw mic PCM to the server over WebSocket and turns its
/// {frequency, confidence} replies into the same NoteResult shape
/// AudioService (local YIN) produces, so callers don't need to know which
/// detector is actually running.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'note_utils.dart';
import 'pitch_detection_service.dart';
import 'pitch_server_config.dart';

class CrepePitchService implements PitchDetectionService {
  final _recorder = AudioRecorder();
  IOWebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription? _wsSub;

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
  bool get isRunning => _isRunning;

  double? _targetFreq;

  Future<void> preloadCrepe() async {}

  /// Returns false if the CREPE server isn't reachable or the mic
  /// permission is denied — caller should fall back to local YIN.
  @override
  Future<bool> start({double? targetFreq, bool enableMonitoring = true}) async {
    if (_isRunning) return true;
    _targetFreq = targetFreq;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return false;

    try {
      await http
          .get(Uri.parse(PitchServerConfig.healthUrl))
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('CREPE server unreachable at ${PitchServerConfig.healthUrl}: $e');
      return false;
    }

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(PitchServerConfig.wsUrl),
        connectTimeout: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('CREPE WebSocket connect failed: $e');
      _channel = null;
      return false;
    }

    _wsSub = _channel!.stream.listen(
      _handleServerMessage,
      onError: (e) => debugPrint('CREPE WebSocket error: $e'),
      onDone: () => debugPrint('CREPE WebSocket closed'),
    );

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      // Matches crepe_server.py's default FLUTTER_SAMPLE_RATE (44100); the
      // server resamples to 16kHz internally for the CREPE model itself.
      sampleRate: 44100,
      numChannels: 1,
      autoGain: false,
      echoCancel: true,
      noiseSuppress: true,
      // Same fix as AudioService: don't let the recorder interrupt/duck
      // the karaoke playback when it starts.
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
      debugPrint('CREPE mic start failed: $e');
      await _wsSub?.cancel();
      await _channel?.sink.close();
      _channel = null;
      return false;
    }

    _isRunning = true;
    _audioSub = stream.listen(
      (bytes) {
        _bytesController.add(bytes.toList());
        _channel?.sink.add(bytes);
      },
      onError: (e) => debugPrint('CREPE mic stream error: $e'),
      onDone: () => _isRunning = false,
    );

    return true;
  }

  void _handleServerMessage(dynamic message) {
    if (_resultController == null || _resultController!.isClosed) return;
    try {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final freq = (json['frequency'] as num).toDouble();
      final confidence = (json['confidence'] as num).toDouble();
      if (freq <= 0) {
        _resultController!.add(NoteResult.silent());
        return;
      }
      _resultController!.add(analyzeFrequency(
        freq,
        targetFreq: _targetFreq,
        confidence: confidence,
      ));
    } catch (e) {
      debugPrint('CREPE message parse error: $e');
    }
  }

  void setMonitoring(bool enabled) {
    // Kept for API parity with AudioService — CREPE mode has no local
    // toggle since detection always happens server-side.
  }

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    _isRunning = false;
    _audioSub?.cancel();
    _audioSub = null;
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _resultController?.close();
    _resultController = null;
    _bytesController.close();
    _recorder.stop().ignore();
  }
}
