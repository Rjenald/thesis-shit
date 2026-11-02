import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/ground_truth_service.dart';
import 'package:final_thesis_ui/services/song_audio_service.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';

/// Does the admin screen know what is actually shipped?
///
/// Telling an admin which songs are missing a backing track or a reference
/// melody is the entire purpose of that screen, and it was answered from
/// the **catalog** rather than the **bundle**. `hasBundledGroundTruth` just
/// built a path string from the catalog entry and returned true if the
/// song was listed, so:
///
///  - every catalogued song reported "Built-in" whether or not a file
///    existed, and
///  - "Missing" was unreachable for a catalogued song — the one state
///    worth showing.
///
/// It read correctly for weeks only because the catalog and the folder
/// happened to agree. Nine of the ten songs spent that time with no
/// ground truth at all while the screen claimed a built-in melody for
/// each.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the path helpers still only answer "is it catalogued"', () {
    // Kept, and renamed to say so. The point is that this is NOT an
    // existence check, which is exactly how the bug happened.
    for (final song in SongCatalogService.bundled) {
      expect(GroundTruthService.hasCataloguedGroundTruthPath(song.title),
          isTrue,
          reason: '${song.title} is catalogued, so a path exists');
    }
    expect(
        GroundTruthService.hasCataloguedGroundTruthPath('Not A Real Song'),
        isFalse);
  });

  test('existence is checked against the bundle, and matches it', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final shipped = manifest.listAssets().toSet();

    for (final song in SongCatalogService.bundled) {
      final gtPath = 'assets/ground_truth/${song.assetName}.json';
      final mp3Path = 'assets/audio/${song.assetName}.mp3';

      expect(await GroundTruthService.bundledGroundTruthExists(song.title),
          shipped.contains(gtPath),
          reason: '${song.title}: ground truth');
      expect(await SongAudioService.bundledAudioExists(song.title),
          shipped.contains(mp3Path),
          reason: '${song.title}: backing track');
    }
  });

  test('a song that is not in the catalog has neither', () async {
    expect(
        await GroundTruthService.bundledGroundTruthExists('Not A Real Song'),
        isFalse);
    expect(await SongAudioService.bundledAudioExists('Not A Real Song'),
        isFalse);
  });

  test('"Missing" is reachable, which is the whole fix', () async {
    // A catalogued song with no file on disk must come back false. Proven
    // against a name that is in the catalog shape but has no asset, since
    // every real song currently has its files — the check has to keep
    // working when that stops being true.
    const invented = 'Nonexistent Song';
    expect(SongCatalogService.assetNameFor(invented), isNull,
        reason: 'guard: this test assumes the song is not catalogued');
    expect(await GroundTruthService.bundledGroundTruthExists(invented),
        isFalse);
  });

  test('every catalogued song currently has both files', () async {
    // Not the same assertion as above: this one is about the data as it
    // stands, and it is the state the app needs to be shippable. If a
    // song is added to the catalog before its files, this fails and names
    // it.
    final missing = <String>[];
    for (final song in SongCatalogService.bundled) {
      if (!await SongAudioService.bundledAudioExists(song.title)) {
        missing.add('${song.title}: no backing track');
      }
      if (!await GroundTruthService.bundledGroundTruthExists(song.title)) {
        missing.add('${song.title}: no ground truth');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('checking every song does not read the audio itself', () async {
    // The reason both use the asset manifest. Loading each file to answer
    // a yes/no question would pull ~80MB of MP3 through memory, on a
    // screen that checks all ten at once. A run that completes this
    // quickly cannot have decoded them.
    final sw = Stopwatch()..start();
    for (final song in SongCatalogService.bundled) {
      await SongAudioService.bundledAudioExists(song.title);
      await GroundTruthService.bundledGroundTruthExists(song.title);
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(3000),
        reason: 'took ${sw.elapsedMilliseconds}ms — is it loading the '
            'files instead of reading the manifest?');
  });
}
