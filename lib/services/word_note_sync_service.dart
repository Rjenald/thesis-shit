// ════════════════════════════════════════════════════════════════════════════
// word_note_sync_service.dart
// ════════════════════════════════════════════════════════════════════════════
// Groups CREPE pitch frames by Whisper word ranges.
//
// Inputs:
//   - words  : List of WhisperWord  (from WhisperService.transcribe)
//   - frames : List of PitchFrame   (collected during recording)
//
// Output:
//   - List of WordAnalysis (one per word, with notes + dominant + confidence)
//
// Pure Dart, no UI, no I/O — easy to unit-test.
// ════════════════════════════════════════════════════════════════════════════

import 'audio_service_models.dart';
import 'whisper_service.dart';

class WordAnalysis {
  final String word;
  final double start;
  final double end;
  final List<String> notes;
  final String dominantNote;
  final double confidence;

  const WordAnalysis({
    required this.word,
    required this.start,
    required this.end,
    required this.notes,
    required this.dominantNote,
    required this.confidence,
  });

  bool get hasNotes => notes.isNotEmpty;
  int get confidencePercent => (confidence * 100).round();

  @override
  String toString() =>
      '$word [${start.toStringAsFixed(2)}-${end.toStringAsFixed(2)}s] '
      '→ ${notes.join(" ")}  (dom: $dominantNote, $confidencePercent%)';
}

class WordNoteSyncService {
  /// Group `frames` into `words`. O(n + m).
  ///
  /// Frames whose `timeSec` falls inside `[word.start, word.end]` are
  /// assigned to that word. Frames between words are dropped.
  static List<WordAnalysis> sync({
    required List<WhisperWord> words,
    required List<PitchFrame> frames,
  }) {
    if (words.isEmpty) return [];

    // Defensive sort — AudioService normally produces them in order already.
    final sorted = [...frames]
      ..sort((a, b) => a.timeSec.compareTo(b.timeSec));

    final results = <WordAnalysis>[];
    int frameIdx = 0;

    for (final w in words) {
      // Skip past frames that ended before this word started.
      while (frameIdx < sorted.length && sorted[frameIdx].timeSec < w.start) {
        frameIdx++;
      }

      // Collect frames whose timestamp falls inside this word.
      final inWord = <PitchFrame>[];
      var cursor = frameIdx;
      while (cursor < sorted.length && sorted[cursor].timeSec <= w.end) {
        final f = sorted[cursor];
        if (f.note.isNotEmpty) inWord.add(f);
        cursor++;
      }

      if (inWord.isEmpty) {
        results.add(WordAnalysis(
          word: w.text,
          start: w.start,
          end: w.end,
          notes: const [],
          dominantNote: '',
          confidence: 0.0,
        ));
        continue;
      }

      // Dominant note: weighted by confidence so noisy frames don't dominate.
      final weighted = <String, double>{};
      for (final f in inWord) {
        weighted[f.note] = (weighted[f.note] ?? 0) + f.confidence;
      }
      final dominant =
          weighted.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

      // Unique note sequence (preserves order, removes immediate repeats).
      final seq = <String>[];
      for (final f in inWord) {
        if (seq.isEmpty || seq.last != f.note) seq.add(f.note);
      }

      final avgConf =
          inWord.map((f) => f.confidence).reduce((a, b) => a + b) /
              inWord.length;

      results.add(WordAnalysis(
        word: w.text,
        start: w.start,
        end: w.end,
        notes: seq,
        dominantNote: dominant,
        confidence: avgConf,
      ));
    }

    return results;
  }
}