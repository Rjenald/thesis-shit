import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/ground_truth_service.dart';
import 'package:final_thesis_ui/services/song_audio_service.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';

/// Loads every catalogued song's ground truth through the same code path
/// the app uses. A song whose ground truth fails to load silently loses its
/// whole Pitch Timeline — the result screen still shows a score and drills,
/// so the failure looks like a display bug rather than a missing file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogued song resolves to a loadable ground truth', () async {
    final failures = <String>[];

    for (final song in SongCatalogService.bundled) {
      final path = GroundTruthService.assetPathFor(song.title);
      if (path == null) {
        failures.add('${song.title}: assetPathFor returned null');
        continue;
      }

      // Does the bundle actually contain this key? Spaces and '&' in asset
      // names are the kind of thing that works until it doesn't.
      try {
        await rootBundle.loadString(path);
      } catch (e) {
        failures.add('${song.title}: rootBundle could not load "$path"');
        continue;
      }

      final syllables = await GroundTruthService.loadForSong(song.title);
      if (syllables == null) {
        failures.add('${song.title}: loadForSong returned null');
      } else if (syllables.isEmpty) {
        failures.add('${song.title}: parsed to ZERO syllables '
            '(hasGroundTruth would be false -> no Pitch Timeline)');
      } else {
        // ignore: avoid_print
        print('${song.title.padRight(26)} ${syllables.length} syllables, '
            '${syllables.first.startTime.inMilliseconds / 1000}s .. '
            '${syllables.last.endTime.inMilliseconds / 1000}s');
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every catalogued song resolves to a bundled backing track', () async {
    final failures = <String>[];
    for (final song in SongCatalogService.bundled) {
      final ref = SongAudioService.resolve(song.title);
      if (ref == null) {
        failures.add('${song.title}: no audio resolved');
        continue;
      }
      try {
        await rootBundle.load(ref.path);
      } catch (_) {
        failures.add('${song.title}: rootBundle could not load "${ref.path}"');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
