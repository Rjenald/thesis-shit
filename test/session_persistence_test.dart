import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/lyric_alignment_service.dart';
import 'package:final_thesis_ui/models/session_result.dart';

SessionResult _session({LyricAlignmentResult? alignment}) => SessionResult(
      songTitle: 'Nasa Iyo Na Ang Lahat',
      songArtist: 'Daniel Padilla',
      songImage: '',
      completedAt: DateTime(2026, 9, 17, 14, 30),
      lyricResults: const [],
      durationSeconds: 42,
      lyricAlignment: alignment,
    );

/// Round-trips through real JSON text, the way SessionStorageService does,
/// so a field that silently fails to encode can't pass.
SessionResult _reload(SessionResult s) => SessionResult.fromJson(
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

void main() {
  group('SessionResult lyric alignment persistence', () {
    test('survives being saved and reopened from the library', () {
      final saved = _session(
        alignment: const LyricAlignmentResult([
          AlignedWord(
            expectedWord: 'Nasa',
            expectedTime: Duration(milliseconds: 12110),
            recognizedWord: 'Nasa',
            recognizedTime: Duration(milliseconds: 12300),
          ),
          AlignedWord(
            expectedWord: 'lahat',
            expectedTime: Duration(milliseconds: 13400),
          ),
        ]),
      );

      final alignment = _reload(saved).lyricAlignment;

      expect(alignment, isNotNull);
      expect(alignment!.words, hasLength(2));

      final matched = alignment.words.first;
      expect(matched.expectedWord, 'Nasa');
      expect(matched.recognizedWord, 'Nasa');
      expect(matched.expectedTime, const Duration(milliseconds: 12110));
      expect(matched.recognizedTime, const Duration(milliseconds: 12300));
      expect(matched.matched, isTrue);
      expect(matched.timingOffsetMs, 190);

      final missed = alignment.words.last;
      expect(missed.matched, isFalse,
          reason: 'a word that was never heard must stay unmatched');
      expect(missed.recognizedWord, isNull);
      expect(missed.recognizedTime, isNull);
      expect(missed.timingOffsetMs, isNull);
    });

    test('derived stats are identical after reload', () {
      final saved = _session(
        alignment: const LyricAlignmentResult([
          AlignedWord(
            expectedWord: 'a',
            expectedTime: Duration(milliseconds: 1000),
            recognizedWord: 'a',
            recognizedTime: Duration(milliseconds: 1200),
          ),
          AlignedWord(
            expectedWord: 'b',
            expectedTime: Duration(milliseconds: 2000),
            recognizedWord: 'b',
            recognizedTime: Duration(milliseconds: 1900),
          ),
          AlignedWord(expectedWord: 'c', expectedTime: Duration(seconds: 3)),
        ]),
      );

      final before = saved.lyricAlignment!;
      final after = _reload(saved).lyricAlignment!;

      expect(after.matchedCount, before.matchedCount);
      expect(after.totalCount, before.totalCount);
      expect(after.matchRatePercent, before.matchRatePercent);
      expect(after.avgAbsTimingOffsetMs, before.avgAbsTimingOffsetMs);
    });

    test('a session with no alignment reloads as null, not a crash', () {
      expect(_reload(_session()).lyricAlignment, isNull);
    });

    test('sessions saved before alignment existed still load', () {
      // Exactly what an older stored session looks like: no key at all.
      final legacy = {
        'songTitle': 'Ulap',
        'songArtist': 'Cueshé',
        'songImage': '',
        'completedAt': DateTime(2026, 1, 1).toIso8601String(),
        'durationSeconds': 30,
        'lyricResults': <dynamic>[],
      };

      final loaded = SessionResult.fromJson(legacy);

      expect(loaded.lyricAlignment, isNull);
      expect(loaded.songTitle, 'Ulap');
      expect(loaded.singingSegments, isEmpty);
    });
  });
}
