import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/ground_truth_service.dart';
import 'package:final_thesis_ui/services/song_audio_service.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';

/// Guards the two ways the catalog can disagree with what is on disk.
///
/// They are not equally bad, so they are not treated the same:
///
///  - **No backing track** is fatal. The song is offered, tapped, and
///    dead-ends with nothing to sing over. Always a failure.
///
///  - **No ground truth** is a degradation. The song plays, gets recorded
///    and transcribed; it just has no target melody, so there is no score
///    and no Pitch Timeline. That is the normal state while ground truth
///    is still being authored, so it is reported rather than failed.
///
///  - **Ground truth that exists but will not load** is the failure worth
///    catching, and the one that actually happened: a filename that did
///    not match the convention (`Dadalhin- Regine Velasquez.json`) or a
///    file that parsed to zero syllables. The result screen still showed a
///    score and drills, so it looked like a display bug rather than a
///    missing file. Always a failure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        failures.add('${song.title}: rootBundle could not load "${ref.path}" '
            '— check the "<Title> - <Artist>.mp3" filename exactly');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('any bundled ground truth loads and parses to real syllables',
      () async {
    final failures = <String>[];
    final absent = <String>[];
    var loaded = 0;

    for (final song in SongCatalogService.bundled) {
      final path = GroundTruthService.assetPathFor(song.title);
      if (path == null) {
        failures.add('${song.title}: assetPathFor returned null');
        continue;
      }

      // Is it bundled at all? Spaces and '&' in asset names are the kind
      // of thing that works until it doesn't.
      try {
        await rootBundle.loadString(path);
      } catch (_) {
        absent.add(song.title);
        continue;
      }

      // It IS bundled, so from here on anything short of real syllables
      // is a genuine failure, not work still to do.
      final syllables = await GroundTruthService.loadForSong(song.title);
      if (syllables == null) {
        failures.add('${song.title}: bundled at "$path" but loadForSong '
            'returned null');
      } else if (syllables.isEmpty) {
        failures.add('${song.title}: bundled at "$path" but parsed to ZERO '
            'syllables — hasGroundTruth is false, so no Pitch Timeline');
      } else {
        loaded++;
        // ignore: avoid_print
        print('${song.title.padRight(26)} ${syllables.length} notes, '
            '${syllables.first.startTime.inMilliseconds / 1000}s .. '
            '${syllables.last.endTime.inMilliseconds / 1000}s');
      }
    }

    if (absent.isNotEmpty) {
      // ignore: avoid_print
      print('\nNo ground truth yet (playable, but no score or Pitch '
          'Timeline): ${absent.join(', ')}');
    }
    // ignore: avoid_print
    print('$loaded of ${SongCatalogService.bundled.length} catalogued songs '
        'have loadable ground truth.');

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('no ground-truth file is orphaned by a catalog entry', () async {
    // The reverse drift: a file authored under a name the catalog does not
    // list is silently never used. Caught here because the symptom in the
    // app — a song with no Pitch Timeline — looks identical to not having
    // authored it at all.
    final titles = {
      for (final s in SongCatalogService.bundled) s.assetName,
    };

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final orphans = manifest
        .listAssets()
        .where((k) => k.startsWith('assets/ground_truth/') &&
            k.endsWith('.json') &&
            // `<stem>.words.json` sits beside `<stem>.json` and holds the
            // word onsets that time the scrolling lyrics, not notes. It
            // is not a ground-truth file and has no catalog entry of its
            // own, so matching on ".json" alone reported it as orphaned.
            !k.endsWith('.words.json'))
        .map((k) => k
            .replaceFirst('assets/ground_truth/', '')
            .replaceFirst(RegExp(r'\.json$'), ''))
        .where((name) => !titles.contains(name))
        .toList();

    expect(orphans, isEmpty,
        reason: 'ground truth exists for ${orphans.join(', ')} but no '
            'catalog entry has that "<Title> - <Artist>" name, so the app '
            'will never load it');
  });
}
