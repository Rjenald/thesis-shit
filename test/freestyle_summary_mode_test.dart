import 'package:flutter_test/flutter_test.dart';

import 'package:final_thesis_ui/models/freestyle_summary.dart';
import 'package:final_thesis_ui/models/word_note_entry.dart';

/// Search & Sing and Freestyle share one store, so which section of the
/// library a take lands in comes down entirely to whether a song title was
/// persisted with it. These tests pin that split, and pin that recordings
/// saved before the field existed still decode.
void main() {
  FreestyleSummary make({String? songTitle, String? songArtist}) =>
      FreestyleSummary(
        id: 'r1',
        createdAt: DateTime(2026, 3, 14, 9, 30),
        durationSeconds: 42,
        audioRef: 'local:r1',
        songTitle: songTitle,
        songArtist: songArtist,
        words: const [
          WordNoteEntry(
            word: 'mahal',
            syllableNotes: ['C4', 'D4'],
            startTimeMs: 0,
            endTimeMs: 500,
          ),
        ],
      );

  group('mode split', () {
    test('a take with a song is Search & Sing', () {
      final s = make(songTitle: 'Ere', songArtist: 'Juan Karlos');
      expect(s.isSearchAndSing, isTrue);
      expect(s.displayTitle, 'Ere');
    });

    test('a take with no song is Freestyle', () {
      final s = make();
      expect(s.isSearchAndSing, isFalse);
      expect(s.displayTitle, 'Freestyle recording');
    });

    test('a blank or whitespace title counts as Freestyle', () {
      // Otherwise an empty string from an upstream field would put an
      // untitled take in the Search & Sing section with no name on it.
      expect(make(songTitle: '').isSearchAndSing, isFalse);
      expect(make(songTitle: '   ').isSearchAndSing, isFalse);
      expect(make(songTitle: '\n').isSearchAndSing, isFalse);
    });

    test('displayTitle trims a padded title', () {
      expect(make(songTitle: '  Tahanan  ').displayTitle, 'Tahanan');
    });
  });

  group('persistence', () {
    test('the song survives a round trip', () {
      final s = make(songTitle: 'Binibini', songArtist: 'Zack Tabudlo');
      final back = FreestyleSummary.fromJson(s.toJson());

      expect(back.songTitle, 'Binibini');
      expect(back.songArtist, 'Zack Tabudlo');
      expect(back.isSearchAndSing, isTrue);
      // The fields that already worked must keep working.
      expect(back.id, s.id);
      expect(back.createdAt, s.createdAt);
      expect(back.durationSeconds, s.durationSeconds);
      expect(back.audioRef, s.audioRef);
      expect(back.words.single.word, 'mahal');
      expect(back.words.single.syllableNotes, ['C4', 'D4']);
    });

    test('a Freestyle take round trips without song keys', () {
      final s = make();
      final json = s.toJson();

      // Omitted rather than written as null, so an old reader that does
      // not know these keys sees exactly the payload it used to.
      expect(json.containsKey('songTitle'), isFalse);
      expect(json.containsKey('songArtist'), isFalse);
      expect(FreestyleSummary.fromJson(json).isSearchAndSing, isFalse);
    });

    test('a recording saved before this field existed still decodes', () {
      // Exactly the shape FreestyleStorageService wrote previously.
      final legacy = {
        'id': 'old-1',
        'createdAt': '2026-01-05T08:15:00.000',
        'durationSeconds': 17,
        'audioRef': 'local:old-1',
        'words': [
          {
            'word': 'kita',
            'syllableNotes': ['E4'],
            'startTimeMs': 0,
            'endTimeMs': 300,
          },
        ],
      };

      final s = FreestyleSummary.fromJson(legacy);
      expect(s.id, 'old-1');
      expect(s.songTitle, isNull);
      expect(s.isSearchAndSing, isFalse,
          reason: 'an old entry should list as Freestyle, not vanish');
      expect(s.displayTitle, 'Freestyle recording');
      expect(s.words.single.word, 'kita');
    });

    test('a null songArtist on a titled take is tolerated', () {
      // lrclib results don't always carry an artist.
      final s = make(songTitle: 'Ulap');
      final back = FreestyleSummary.fromJson(s.toJson());
      expect(back.isSearchAndSing, isTrue);
      expect(back.songArtist, isNull);
    });
  });

  group('library sectioning', () {
    test('a mixed list splits with nothing lost and nothing duplicated', () {
      final all = [
        make(songTitle: 'Ere'),
        make(),
        make(songTitle: 'Tahanan'),
        make(songTitle: ''),
        make(),
      ];

      final searchAndSing = all.where((s) => s.isSearchAndSing).toList();
      final freestyle = all.where((s) => !s.isSearchAndSing).toList();

      expect(searchAndSing.length, 2);
      expect(freestyle.length, 3);
      expect(searchAndSing.length + freestyle.length, all.length);
    });
  });
}
