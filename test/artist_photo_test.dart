import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';
import 'package:final_thesis_ui/widgets/song_cover_art.dart';

/// The home page's artist row.
///
/// Two things were wrong with it. It drew each artist as their first
/// song's album cover, so a row headed "Artists" was really a row of
/// sleeves — and the artist with two songs in the catalogue appeared with
/// the same sleeve as the song right above. Then the covers stopped being
/// URLs and became bundled assets, and the row kept calling NetworkImage
/// on them: an asset path is not a URL, so every fetch failed, and the
/// `onError` callback discarded the failure. The result was ten empty dark
/// circles with nothing in the logs explaining them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogued artist has a bundled photo', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final shipped = manifest.listAssets().toSet();

    final missing = <String>[];
    for (final artist in _catalogueArtists()) {
      final path = SongCatalogService.artistImageFor(artist);
      if (!shipped.contains(path)) missing.add('$artist: $path');
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('the photo is found by the artist name alone', () {
    // Not by song: two songs by one artist must share one file, or adding
    // a second song means remembering to duplicate an image.
    for (final song in SongCatalogService.bundled) {
      expect(song.artistImagePath, 'assets/artists/${song.artist}.jpg',
          reason: song.title);
    }
  });

  test('an artist photo is not the song cover', () async {
    // The regression this replaces: these two paths used to be the same
    // string, which is why the row showed album art.
    for (final song in SongCatalogService.bundled) {
      expect(song.artistImagePath, isNot(song.imagePath),
          reason: '${song.artist} would be shown as a sleeve again');
    }
  });

  test('the photos actually decode', () async {
    // In the manifest is not the same as usable: a truncated or
    // mislabelled file passes the first test and fails on a phone.
    for (final artist in _catalogueArtists()) {
      final data =
          await rootBundle.load(SongCatalogService.artistImageFor(artist));
      expect(data.lengthInBytes, greaterThan(1000),
          reason: '$artist is suspiciously small');
      final bytes = data.buffer.asUint8List();
      expect(bytes[0], 0xFF, reason: '$artist is not a JPEG');
      expect(bytes[1], 0xD8, reason: '$artist is not a JPEG');
    }
  });

  test('no artist is left without a name to look up', () {
    for (final song in SongCatalogService.bundled) {
      expect(song.artist.trim(), isNotEmpty, reason: song.title);
    }
    // An empty name has no file; returning a path would ask Flutter to
    // load 'assets/artists/.jpg'.
    expect(SongCatalogService.artistImageFor(''), '');
  });

  test('every shipped photo belongs to a catalogued artist', () async {
    // The other direction: a file left behind after an artist is renamed
    // ships in the APK forever and is never shown.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final artists = _catalogueArtists();
    final orphans = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/artists/'))
        .where((a) => !artists
            .any((artist) => a == SongCatalogService.artistImageFor(artist)))
        .toList();
    expect(orphans, isEmpty, reason: 'unused: ${orphans.join(', ')}');
  });

  testWidgets('a missing photo falls back to a person, not a note',
      (tester) async {
    // What an admin-added artist gets: a path to a file that is not there.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SongCoverArt(
            image: 'assets/artists/Nobody At All.jpg',
            size: 72,
            borderRadius: 36,
            placeholderIcon: Icons.person,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.music_note), findsNothing);
  });

  testWidgets('songs still get the note placeholder', (tester) async {
    // The new parameter must not change what every other caller sees.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: SongCoverArt(image: ''))),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  test('the artist row no longer fetches its images over the network', () {
    // Source-level, because the failure mode was silent: NetworkImage on
    // an asset path throws into an onError that threw the error away, so
    // neither a test nor the console would have shown anything. The row
    // renders through SongCoverArt now, which picks the loader from the
    // path and has a visible fallback.
    final src =
        File('lib/screens/normal_user/home_page.dart').readAsStringSync();
    // Comments stripped first: the replaced code is described in one, and
    // a test that cannot tell a warning from the thing it warns about is
    // a test that fails when someone documents the fix.
    final code = src
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code, isNot(contains('NetworkImage')),
        reason: 'the artist row must not load assets over HTTP');

    final row = code.substring(code.indexOf('_buildArtistsRow'));
    expect(row, contains('SongCoverArt'));
    expect(row, contains('Icons.person'));
  });
}

List<String> _catalogueArtists() =>
    SongCatalogService.bundled.map((s) => s.artist).toSet().toList();
