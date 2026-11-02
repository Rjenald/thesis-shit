import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:final_thesis_ui/core/note_utils.dart' show PitchFeedback;
import 'package:final_thesis_ui/models/session_result.dart';
import 'package:final_thesis_ui/models/singing_segment.dart';

/// What a saved karaoke session has to carry, now that scoring is pitch
/// only.
///
/// Recognized words are displayed, never compared against the lyrics, so
/// there is no word alignment to persist any more. What must survive a
/// save/reload is the pitch comparison — [SessionResult.singingSegments] —
/// because the score is derived from it, and a session that lost its
/// segments on reload would show a different score in the library than it
/// did right after singing.
SessionResult _session({List<SingingSegment> segments = const []}) =>
    SessionResult(
      songTitle: 'Nasa Iyo Na Ang Lahat',
      songArtist: 'Daniel Padilla',
      songImage: '',
      completedAt: DateTime(2026, 9, 17, 14, 30),
      lyricResults: const [],
      durationSeconds: 42,
      singingSegments: segments,
    );

SingingSegment _segment({
  String syllable = 'Na',
  String? actualWord = 'Nasa',
  String? actualNote = 'C4',
  double? actualFrequency = 261.63,
  double? differenceCents = 12.0,
  PitchFeedback status = PitchFeedback.correct,
}) =>
    SingingSegment(
      syllable: syllable,
      startTimeMs: 12110,
      endTimeMs: 12480,
      targetNote: 'C4',
      targetFrequency: 261.63,
      actualWord: actualWord,
      actualWordIndex: actualWord == null ? null : 0,
      actualNote: actualNote,
      actualFrequency: actualFrequency,
      differenceCents: differenceCents,
      status: status,
      confidence: 0.91,
      frameFrequencies: const [260.1, 261.9, 262.4],
    );

/// Round-trips through real JSON text, the way SessionStorageService does,
/// so a field that silently fails to encode cannot pass.
SessionResult _reload(SessionResult s) => SessionResult.fromJson(
    jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);

void main() {
  group('pitch segments survive a save and reload', () {
    test('every scored field comes back unchanged', () {
      final saved = _session(segments: [_segment()]);
      final reloaded = _reload(saved);

      expect(reloaded.singingSegments, hasLength(1));
      final seg = reloaded.singingSegments.single;

      expect(seg.targetNote, 'C4');
      expect(seg.targetFrequency, closeTo(261.63, 1e-6));
      expect(seg.actualNote, 'C4');
      expect(seg.actualFrequency, closeTo(261.63, 1e-6));
      expect(seg.differenceCents, closeTo(12.0, 1e-6));
      expect(seg.status, PitchFeedback.correct);
      expect(seg.confidence, closeTo(0.91, 1e-6));
      expect(seg.startTimeMs, 12110);
      expect(seg.endTimeMs, 12480);
    });

    test('raw frame frequencies are deliberately dropped on reload', () {
      // Documented on SingingSegment: they are excluded from toJson so a
      // saved library does not carry raw per-frame data for every
      // syllable of every take. A reloaded session loses only the
      // pitch-movement mini view, not anything scored. Pinned here so
      // "fixing" it later is a deliberate decision rather than an
      // accident.
      final saved = _session(segments: [_segment()]);
      expect(saved.singingSegments.single.frameFrequencies, hasLength(3));
      expect(_reload(saved).singingSegments.single.frameFrequencies, isEmpty);
    });

    test('the score is identical after reload', () {
      // The thing a user would actually notice: a take scoring 50% right
      // after singing must not score differently in the library.
      final saved = _session(segments: [
        _segment(status: PitchFeedback.correct),
        _segment(status: PitchFeedback.tooHigh, actualNote: 'C#4'),
      ]);

      expect(_reload(saved).score, saved.score);
      expect(_reload(saved).stars, saved.stars);
    });

    test('a recognized word is kept for display', () {
      // Words are shown, not scored — but they still have to persist, or
      // reopening a take would lose what the app heard.
      final seg = _reload(_session(segments: [_segment()])).singingSegments
          .single;
      expect(seg.actualWord, 'Nasa');
      expect(seg.actualWordIndex, 0);
    });

    test('a syllable nothing was sung over reloads as no-signal', () {
      final saved = _session(segments: [
        _segment(
          actualWord: null,
          actualNote: null,
          actualFrequency: null,
          differenceCents: null,
          status: PitchFeedback.noSignal,
        ),
      ]);

      final seg = _reload(saved).singingSegments.single;
      expect(seg.actualNote, isNull);
      expect(seg.actualFrequency, isNull);
      expect(seg.differenceCents, isNull);
      expect(seg.actualWord, isNull);
      expect(seg.status, PitchFeedback.noSignal);
    });

    test('the ground-truth syllable text is still carried', () {
      // Not user-facing any more (the detail sheet shows it only in debug
      // builds), but it is how a developer checks a ground-truth file is
      // lined up with the audio, so it must not be dropped on reload.
      expect(
        _reload(_session(segments: [_segment(syllable: 'ha')]))
            .singingSegments
            .single
            .syllable,
        'ha',
      );
    });
  });

  group('older saved sessions still load', () {
    test('a session stored with a lyricAlignment key is read, not refused',
        () {
      // Word alignment used to be persisted on the session. Those saved
      // sessions are still on real devices, so an unknown key has to be
      // ignored rather than throwing and losing the whole library entry.
      final legacy = {
        'songTitle': 'Ulap',
        'songArtist': 'Rob Daniel',
        'songImage': '',
        'completedAt': DateTime(2026, 1, 1).toIso8601String(),
        'durationSeconds': 30,
        'lyricResults': <dynamic>[],
        'singingSegments': <dynamic>[],
        'lyricAlignment': {
          'words': [
            {
              'expectedWord': 'Nasa',
              'expectedTimeMs': 12110,
              'recognizedWord': 'Nasa',
              'recognizedTimeMs': 12300,
            },
          ],
        },
      };

      final loaded = SessionResult.fromJson(legacy);

      expect(loaded.songTitle, 'Ulap');
      expect(loaded.durationSeconds, 30);
      expect(loaded.singingSegments, isEmpty);
    });

    test('a session with no segments key at all loads', () {
      final legacy = {
        'songTitle': 'Ere',
        'songArtist': 'Juan Karlos',
        'songImage': '',
        'completedAt': DateTime(2026, 1, 1).toIso8601String(),
        'durationSeconds': 30,
        'lyricResults': <dynamic>[],
      };

      final loaded = SessionResult.fromJson(legacy);
      expect(loaded.songTitle, 'Ere');
      expect(loaded.singingSegments, isEmpty);
      expect(loaded.score, 0);
    });

    test('a saved session no longer writes a lyricAlignment key', () {
      final json = _session(segments: [_segment()]).toJson();
      expect(json.containsKey('lyricAlignment'), isFalse);
      expect(json.containsKey('singingSegments'), isTrue);
    });
  });
}
