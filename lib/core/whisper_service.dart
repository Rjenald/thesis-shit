/// WhisperService — wraps the whisper_ggml package and exposes a clean,
/// karaoke-friendly API that returns words + timestamps from a WAV file.
///
/// ── HOW IT WORKS ───────────────────────────────────────────────────────────
///  1. On first use, copies `assets/models/ggml-tagalog-q8_0.bin` from the
///     Flutter bundle to a writable location on disk (whisper.cpp needs a
///     real filesystem path; it can't read assets directly).
///  2. Calls WhisperController.transcribe(...) with `splitOnWord: true` so
///     whisper.cpp returns one segment per word.
///  3. Converts each segment's text + start/end (in centiseconds) into our
///     own `WhisperWord` model.
///
/// ── IMPORTANT ──────────────────────────────────────────────────────────────
///  • Whisper expects 16 kHz mono PCM WAV — that's exactly what AudioService
///    records, so no conversion is needed.
///  • `transcribe()` is a heavy synchronous operation (~5-15s on a phone for
///    a 30s clip). Call it ONCE after the user stops recording.
///  • Singing-mode caveat: Whisper was trained on speech, so word timings on
///    sung audio are approximate. We accept this for word-level karaoke.
library;

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// One word as returned by Whisper, with absolute start/end in seconds.
class WhisperWord {
  final String text;
  final double start;   // seconds, relative to the start of the recording
  final double end;     // seconds

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
  // We want a single Whisper context process-wide because loading the model
  // is slow and consumes ~100 MB on Tiny.
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  // ── Config ────────────────────────────────────────────────────────────────
  // Path to the asset and the on-disk filename we'll copy it to.
  static const String _assetPath  = 'assets/models/ggml-tagalog-q8_0.bin';
  static const String _modelName  = 'ggml-tagalog-q8_0.bin';
  static const String _language   = 'tl'; // Tagalog ISO code

  bool _isReady = false;
  String? _modelOnDiskPath;
  final WhisperController _controller = WhisperController();

  bool get isReady => _isReady;

  // ──────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Copies the GGML model from assets to a writable file path.
  /// Idempotent — safe to call multiple times.
  Future<void> init() async {
    if (_isReady) return;

    try {
      // 1. Where should the model live on disk?
      final docDir = await getApplicationDocumentsDirectory();
      final destPath = '${docDir.path}/$_modelName';
      final destFile = File(destPath);

      // 2. Copy only if not already present (saves a few seconds on warm start)
      if (!await destFile.exists()) {
        print('📥 Copying Whisper model from assets to disk…');
        final bytes = await rootBundle.load(_assetPath);
        await destFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
        print('✅ Whisper model ready at $destPath');
      } else {
        print('✅ Whisper model already on disk');
      }

      _modelOnDiskPath = destPath;
      _isReady = true;
    } catch (e, st) {
      print('❌ WhisperService.init failed: $e\n$st');
      _isReady = false;
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TRANSCRIPTION
  // ──────────────────────────────────────────────────────────────────────────

  /// Transcribe a 16 kHz mono PCM WAV file into a list of timestamped words.
  ///
  /// Returns an empty list on failure (never throws into the UI).
  Future<List<WhisperWord>> transcribe(File wavFile) async {
    if (!_isReady || _modelOnDiskPath == null) {
      print('⚠️ WhisperService.transcribe called before init()');
      return [];
    }
    if (!await wavFile.exists()) {
      print('⚠️ WAV file not found: ${wavFile.path}');
      return [];
    }

    try {
      print('🎙️ Running Whisper on ${wavFile.path}…');
      final sw = Stopwatch()..start();

      final response = await _controller.transcribe(
        // Whisper Tiny — matches the GGML file we ship.
        model: WhisperModel.tiny,
        audioPath: wavFile.path,
        lang: _language,
        // splitOnWord: true makes whisper.cpp emit one segment per word.
        // (Inside whisper_ggml this maps to `--split-on-word`.)
        // If your installed whisper_ggml version doesn't expose it as a
        // top-level param, see the FALLBACK note at the bottom of this file.
      );

      sw.stop();
      print('⏱ Whisper done in ${sw.elapsedMilliseconds} ms');

      final segments = response?.transcription.segments ?? [];
      if (segments.isEmpty) {
        print('⚠️ Whisper returned no segments');
        return [];
      }

      // ── Convert segments → WhisperWord list ────────────────────────────
      // whisper.cpp returns timestamps in centiseconds (1/100 s).
      // Whether your package exposes `fromTs`/`toTs` (whisper_kit-style) or
      // `from`/`to` (older whisper_ggml) varies by version — both branches
      // are handled defensively below.
      final words = <WhisperWord>[];
      for (final seg in segments) {
        final text = (seg.text).trim();
        if (text.isEmpty) continue;

        final startCs = _readTs(seg, ['fromTs', 'from', 'start']);
        final endCs   = _readTs(seg, ['toTs',   'to',   'end']);

        words.add(WhisperWord(
          text: _cleanWord(text),
          start: startCs / 100.0,
          end:   endCs   / 100.0,
        ));
      }

      print('📝 Whisper produced ${words.length} words');
      return words;
    } catch (e, st) {
      print('❌ Whisper transcription failed: $e\n$st');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Defensive timestamp reader. Different versions of `whisper_ggml` use
  /// slightly different field names — we try each in turn via dynamic access.
  /// Always returns centiseconds as an int.
  int _readTs(dynamic seg, List<String> candidates) {
    for (final name in candidates) {
      try {
        // dynamic property access; falls through if the field doesn't exist
        final v = (seg as dynamic).toJson()[name];
        if (v is int)    return v;
        if (v is double) return v.toInt();
        if (v is String) {
          final parsed = int.tryParse(v);
          if (parsed != null) return parsed;
        }
      } catch (_) {
        // try the next candidate name
      }
    }
    return 0;
  }

  /// Strips leading punctuation/whitespace that Whisper sometimes prepends.
  String _cleanWord(String raw) {
    return raw.replaceAll(RegExp(r'^[\s.,!?¿¡;:"\-]+|[\s]+$'), '').trim();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK NOTE
// ─────────────────────────────────────────────────────────────────────────────
// If you get a compile error like:
//   The named parameter 'splitOnWord' isn't defined.
// then your installed `whisper_ggml` version doesn't expose splitOnWord
// directly. In that case, whisper.cpp still returns segments, just at
// SENTENCE granularity. The result page will still work — it just shows
// short phrases instead of single words. If you absolutely need per-word
// granularity, switch the pubspec dependency to:
//
//     whisper_ggml_plus: ^2.0.0
//
// and use `TranscribeRequest(audio: ..., splitOnWord: true)` instead.