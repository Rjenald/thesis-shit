import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/data/song_lyrics.dart';
import 'package:final_thesis_ui/services/ground_truth_service.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';

/// Do the lyrics on screen agree with the notes being scored?
///
/// They are produced by completely separate means — lyrics are authored
/// by hand, ground truth is extracted from the vocal stem — so there is
/// nothing that forces them to describe the same recording. When they
/// disagree the app still works perfectly, which is what makes it
/// dangerous: the singer follows the screen, sings at the wrong moment,
/// and gets a bad score that says nothing about their pitch.
///
/// That is not hypothetical. `Nasa Iyo Na Ang Lahat` shipped with lyric
/// timings authored against a different recording: every line appeared
/// **3.74s** before anybody sang it. Nothing else in the project would
/// have caught it — the ground truth passed every duration, range and
/// overlap check, because it was correct. It was the lyrics that were
/// wrong.
///
/// This only runs for songs that have both, so it stays quiet while
/// ground truth is still being authored.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// How far a line may appear before the first note and still be a
  /// reasonable cue rather than a wrong one. Karaoke legitimately shows
  /// a line slightly early so there is time to read it; 1.5s is
  /// generous for that and far below the 3.74s defect.
  const toleranceSeconds = 1.5;

  test('a song\'s first lyric line lands on its first sung note', () async {
    final failures = <String>[];
    final checked = <String>[];

    for (final song in SongCatalogService.bundled) {
      final lyrics = LocalSongLyrics.getLyrics(song.title);
      if (lyrics == null || lyrics.isEmpty) continue;

      final syllables = await GroundTruthService.loadForSong(song.title);
      if (syllables == null || syllables.isEmpty) continue;

      // The first entry is often a "♪ Intro ♪" marker at 0, which is a
      // placeholder and not a line anybody sings.
      final sung = lyrics
          .where((l) => !l.text.contains('♪') && l.timestamp > Duration.zero)
          .toList();
      if (sung.isEmpty) continue;

      final firstLine = sung.first.timestamp.inMilliseconds / 1000.0;
      final firstNote = syllables.first.startTime.inMilliseconds / 1000.0;
      final early = firstNote - firstLine;
      checked.add('${song.title}: line at ${firstLine.toStringAsFixed(2)}s, '
          'note at ${firstNote.toStringAsFixed(2)}s '
          '(${early >= 0 ? "+" : ""}${early.toStringAsFixed(2)}s)');

      if (early > toleranceSeconds) {
        failures.add('${song.title}: the first lyric line appears '
            '${early.toStringAsFixed(2)}s BEFORE the first sung note '
            '(${firstLine.toStringAsFixed(2)}s vs '
            '${firstNote.toStringAsFixed(2)}s). A singer following the '
            'screen will sing early and score badly for no musical '
            'reason. Re-time the lyrics against the ground truth.');
      } else if (early < -toleranceSeconds) {
        // NOT a failure, and not the lyrics' fault. Lyric timings are now
        // derived from measured word onsets, so a line arriving after the
        // first note means the GROUND TRUTH has notes before anybody
        // sang — instrumental bleed in the vocal stem. Six of ten songs
        // had some, up to 58 notes on Mundo.
        //
        // Failing here would blame the one artefact that is right. The
        // notes are checked where note problems belong, by
        // backend/check_ground_truth.py, which reports it against the
        // word onsets directly.
        // ignore: avoid_print
        print('${song.title}: ${(-early).toStringAsFixed(2)}s of notes '
            'before the first lyric line — bleed in the stem, not a '
            'lyric timing problem (see check_ground_truth.py)');
      }
    }

    for (final line in checked) {
      // ignore: avoid_print
      print(line);
    }
    if (checked.isEmpty) {
      // ignore: avoid_print
      print('No song has both bundled lyrics and ground truth yet; '
          'nothing to cross-check.');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('lyrics do not run past the end of the scored notes', () async {
    // The reverse drift: lines still arriving after the vocal has
    // finished means the tail is mistimed even if the opening is right.
    final failures = <String>[];
    for (final song in SongCatalogService.bundled) {
      final lyrics = LocalSongLyrics.getLyrics(song.title);
      final syllables = await GroundTruthService.loadForSong(song.title);
      if (lyrics == null || lyrics.isEmpty) continue;
      if (syllables == null || syllables.isEmpty) continue;

      final lastLine = lyrics.last.timestamp.inMilliseconds / 1000.0;
      final lastNote = syllables.last.endTime.inMilliseconds / 1000.0;
      if (lastLine > lastNote + 5.0) {
        failures.add('${song.title}: the last lyric line is at '
            '${lastLine.toStringAsFixed(1)}s but the last scored note '
            'ends at ${lastNote.toStringAsFixed(1)}s');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
