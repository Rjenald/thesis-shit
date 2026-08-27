/// On-device lyric alignment using Whisper-Tiny (whisper_ggml / whisper.cpp).
///
/// Transcribes the just-recorded mic audio with word-level timestamps, then
/// aligns each recognized word against the reference lyric text using a
/// greedy, time-anchored fuzzy match (recognized words are naturally
/// time-ordered like the reference lyrics, so this avoids full sequence
/// alignment while still handling repeated words/choruses correctly, since
/// a match is only accepted within a few seconds of where that lyric word
/// was expected).
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';
import '../services/lyrics_service.dart' show LrcLine;

class AlignedWord {
  final String expectedWord;
  final Duration expectedTime;
  final String? recognizedWord;
  final Duration? recognizedTime;

  const AlignedWord({
    required this.expectedWord,
    required this.expectedTime,
    this.recognizedWord,
    this.recognizedTime,
  });

  bool get matched => recognizedWord != null;

  /// Positive = sung late, negative = sung early.
  int? get timingOffsetMs =>
      matched ? recognizedTime!.inMilliseconds - expectedTime.inMilliseconds : null;
}

class LyricAlignmentResult {
  final List<AlignedWord> words;
  const LyricAlignmentResult(this.words);

  int get matchedCount => words.where((w) => w.matched).length;
  int get totalCount => words.length;
  double get matchRatePercent => totalCount == 0 ? 0 : matchedCount / totalCount * 100;

  double get avgAbsTimingOffsetMs {
    final offsets = words.where((w) => w.matched).map((w) => w.timingOffsetMs!.abs());
    if (offsets.isEmpty) return 0;
    return offsets.reduce((a, b) => a + b) / offsets.length;
  }
}

class _ExpectedWord {
  final String norm;
  final String raw;
  final Duration time;
  const _ExpectedWord(this.norm, this.raw, this.time);
}

class _RecognizedWord {
  final String norm;
  final String raw;
  final Duration time;
  const _RecognizedWord(this.norm, this.raw, this.time);
}

/// One word recognized by Whisper, with its start/end time in the recording —
/// used when there's no reference lyric to align against (see
/// [transcribeWords]).
class TranscribedWord {
  final String text;
  final Duration startTime;
  final Duration endTime;
  const TranscribedWord({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}

/// Runs Whisper over [recordedWavBytes] and returns raw word-level segments,
/// with no alignment against any expected/reference text. Shared by
/// [alignLyrics] (karaoke mode) and [transcribeWords] (reference-free mode).
/// Returns null if transcription fails or produces nothing usable.
Future<List<WhisperTranscribeSegment>?> _transcribeSegments(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
}) async {
  File? tempWav;
  try {
    // downloadModel() is a no-op (returns the cached path immediately) once
    // the model has been fetched once — transcribe() does NOT download it
    // automatically despite what it might look like; it only resolves the
    // expected local path and fails if nothing is there yet.
    await WhisperController().downloadModel(WhisperModel.tiny);

    final dir = await getTemporaryDirectory();
    tempWav = File('${dir.path}/huni_whisper_${DateTime.now().microsecondsSinceEpoch}.wav');
    await tempWav.writeAsBytes(recordedWavBytes, flush: true);

    final result = await WhisperController().transcribe(
      model: WhisperModel.tiny,
      audioPath: tempWav.path,
      lang: lang,
      withSegments: true,
      splitOnWord: true,
    );

    final segments = result?.transcription.segments;
    if (segments == null || segments.isEmpty) return null;
    return segments;
  } catch (e) {
    debugPrint('Whisper transcription failed: $e');
    return null;
  } finally {
    if (tempWav != null && await tempWav.exists()) {
      try {
        await tempWav.delete();
      } catch (_) {}
    }
  }
}

/// Returns null if transcription fails or produces no usable segments —
/// caller should treat this as "alignment unavailable" and not block on it.
Future<LyricAlignmentResult?> alignLyrics({
  required List<LrcLine> lyrics,
  required Uint8List recordedWavBytes,
  required Duration recordStartOffset,
  String lang = 'tl',
}) async {
  if (lyrics.isEmpty) return null;

  final segments = await _transcribeSegments(recordedWavBytes, lang: lang);
  if (segments == null) return null;

  final expected = _buildExpectedWords(lyrics);
  final recognizedWords = <_RecognizedWord>[];
  for (var i = 0; i < segments.length; i++) {
    final text = segments[i].text.trim();
    if (text.isEmpty) continue;
    recognizedWords.add(_RecognizedWord(
      _normalize(text),
      text,
      recordStartOffset + segments[i].fromTs,
    ));
  }
  if (recognizedWords.isEmpty) return null;

  return LyricAlignmentResult(_align(expected, recognizedWords));
}

/// Transcribes [recordedWavBytes] with word-level timestamps and no
/// alignment against any reference lyrics — for reference-free ("without
/// karaoke") recordings where there's nothing to align against.
/// Returns an empty list if transcription fails or nothing was recognized.
Future<List<TranscribedWord>> transcribeWords(
  Uint8List recordedWavBytes, {
  String lang = 'tl',
}) async {
  final segments = await _transcribeSegments(recordedWavBytes, lang: lang);
  if (segments == null) return [];

  final words = <TranscribedWord>[];
  for (final segment in segments) {
    final text = segment.text.trim();
    if (text.isEmpty) continue;
    words.add(TranscribedWord(
      text: text,
      startTime: segment.fromTs,
      endTime: segment.toTs,
    ));
  }
  return words;
}

List<_ExpectedWord> _buildExpectedWords(List<LrcLine> lyrics) {
  final expected = <_ExpectedWord>[];
  for (var i = 0; i < lyrics.length; i++) {
    final line = lyrics[i];
    final words = line.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) continue;

    final lineStart = line.timestamp;
    final lineEnd = i + 1 < lyrics.length ? lyrics[i + 1].timestamp : lineStart + const Duration(seconds: 5);
    final lineDurMs = (lineEnd - lineStart).inMilliseconds.clamp(500, 20000);

    for (var w = 0; w < words.length; w++) {
      final wordTimeMs = lineStart.inMilliseconds + (lineDurMs * w / words.length).round();
      expected.add(_ExpectedWord(_normalize(words[w]), words[w], Duration(milliseconds: wordTimeMs)));
    }
  }
  return expected;
}

List<AlignedWord> _align(List<_ExpectedWord> expected, List<_RecognizedWord> recognized) {
  const searchWindow = Duration(seconds: 3);
  var rStart = 0;
  final aligned = <AlignedWord>[];

  for (final exp in expected) {
    var bestJ = -1;
    var bestDist = 1 << 30;

    for (var j = rStart; j < recognized.length; j++) {
      final rec = recognized[j];
      final dt = rec.time - exp.time;
      if (dt > searchWindow) break; // recognized words are time-ordered
      if (dt < -searchWindow) continue;

      final dist = _levenshtein(exp.norm, rec.norm);
      final maxAllowed = exp.norm.length <= 3 ? 1 : 2;
      if (dist <= maxAllowed && dist < bestDist) {
        bestDist = dist;
        bestJ = j;
      }
    }

    if (bestJ >= 0) {
      aligned.add(AlignedWord(
        expectedWord: exp.raw,
        expectedTime: exp.time,
        recognizedWord: recognized[bestJ].raw,
        recognizedTime: recognized[bestJ].time,
      ));
      rStart = bestJ + 1;
    } else {
      aligned.add(AlignedWord(expectedWord: exp.raw, expectedTime: exp.time));
    }
  }

  return aligned;
}

String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), '')
      .replaceAll("'", '')
      .trim();
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}
