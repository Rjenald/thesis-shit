// ════════════════════════════════════════════════════════════════════════════
// whisper_service.dart
// ════════════════════════════════════════════════════════════════════════════
// On-device Whisper transcription via the whisper_ggml package.
// Loads ggml-tagalog-q8_0.bin from assets, copies it to a writable path,
// then transcribes a 16 kHz mono WAV into a list of timestamped words.
//
// Singleton — model is heavy (~80 MB) so we only load it once per process.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// One word produced by Whisper, with absolute timestamps in seconds
/// (relative to the start of the recording).
class WhisperWord {
  final String text;
  final double start;
  final double end;

  const WhisperWord({
    required this.text,
    required this.start,
    required this.end,
  });

  @override
  String toString() =>
      '"$text" (${start.toStringAsFixed(2)}-${end.toStringAsFixed(2)}s)';
}

class WhisperService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  // ── Config ────────────────────────────────────────────────────────────────
  static const String _assetPath = 'assets/models/ggml-tagalog-q8_0.bin';
  static const String _modelName = 'ggml-tagalog-q8_0.bin';
  static const String _language  = 'tl'; // Tagalog ISO code

  bool _isReady = false;
  String? _modelOnDiskPath;
  final WhisperController _controller = WhisperController();

  bool get isReady => _isReady;

  // ──────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────────────────────────────────
  // Copy the GGML model from Flutter assets to a writable file path.
  // whisper.cpp can't read from the asset bundle directly — it needs a real
  // filesystem path. Idempotent: safe to call multiple times.
  Future<void> init() async {
    if (_isReady) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final destPath = '${docDir.path}/$_modelName';
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        dev.log('Copying Whisper model from assets…', name: 'WhisperService');
        final bytes = await rootBundle.load(_assetPath);
        await destFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
        dev.log('Whisper model ready at $destPath', name: 'WhisperService');
      } else {
        dev.log('Whisper model already on disk', name: 'WhisperService');
      }

      _modelOnDiskPath = destPath;
      _isReady = true;
    } catch (e, st) {
      dev.log('init failed: $e',
          name: 'WhisperService', error: e, stackTrace: st);
      _isReady = false;
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRANSCRIPTION
  // ──────────────────────────────────────────────────────────────────────────
  // Returns an empty list on any failure (never throws into the UI).
  Future<List<WhisperWord>> transcribe(File wavFile) async {
    if (!_isReady || _modelOnDiskPath == null) {
      dev.log('transcribe() called before init()', name: 'WhisperService');
      return [];
    }
    if (!await wavFile.exists()) {
      dev.log('WAV not found: ${wavFile.path}', name: 'WhisperService');
      return [];
    }

    try {
      final sw = Stopwatch()..start();
      dev.log('Running Whisper on ${wavFile.path}…', name: 'WhisperService');

      final response = await _controller.transcribe(
        model: WhisperModel.tiny,
        audioPath: wavFile.path,
        lang: _language,
      );

      sw.stop();
      dev.log('Whisper done in ${sw.elapsedMilliseconds} ms',
          name: 'WhisperService');

      final segments = response?.transcription.segments ?? [];
      if (segments.isEmpty) {
        dev.log('No segments returned', name: 'WhisperService');
        return [];
      }

      // whisper.cpp timestamps come in centiseconds (1/100 s).
      // Different versions of the package expose either `fromTs`/`toTs` or
      // `from`/`to`. We try each name defensively via dynamic access.
      final words = <WhisperWord>[];
      for (final seg in segments) {
        final text = seg.text.trim();
        if (text.isEmpty) continue;

        final startCs = _readTs(seg, const ['fromTs', 'from', 'start']);
        final endCs   = _readTs(seg, const ['toTs',   'to',   'end']);

        words.add(WhisperWord(
          text: _cleanWord(text),
          start: startCs / 100.0,
          end:   endCs   / 100.0,
        ));
      }

      dev.log('Produced ${words.length} words', name: 'WhisperService');
      return words;
    } catch (e, st) {
      dev.log('transcribe failed: $e',
          name: 'WhisperService', error: e, stackTrace: st);
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────
  // Reads a centisecond timestamp from a segment, trying several possible
  // field names. Returns 0 if none of the candidates exist.
  int _readTs(dynamic seg, List<String> candidates) {
    for (final name in candidates) {
      try {
        final json = (seg as dynamic).toJson();
        if (json is Map && json.containsKey(name)) {
          final v = json[name];
          if (v is int)    return v;
          if (v is double) return v.toInt();
          if (v is String) {
            final parsed = int.tryParse(v);
            if (parsed != null) return parsed;
          }
        }
      } catch (_) {
        // try the next candidate
      }
    }
    return 0;
  }

  // Strips leading/trailing punctuation/whitespace that Whisper sometimes
  // prepends to segment text.
  String _cleanWord(String raw) {
    return raw.replaceAll(RegExp(r'^[\s.,!?¿¡;:"\-]+|[\s]+$'), '').trim();
  }
}