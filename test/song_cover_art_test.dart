import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/song_catalog_service.dart';
import 'package:final_thesis_ui/widgets/song_cover_art.dart';

/// Cover art, now that it ships with the songs.
///
/// It used to be a remote URL per song, and only three of the ten had one,
/// so the rest showed a placeholder icon. Worse, the three that worked
/// only worked online — in an app that bundles its backing tracks, models
/// and ground truth precisely so it runs without a connection. Every song
/// quietly lost its art the moment the network went away, on a screen that
/// was otherwise fully functional.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalogued song points at a bundled cover', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final shipped = manifest.listAssets().toSet();

    final missing = <String>[];
    for (final song in SongCatalogService.bundled) {
      final path = song.imagePath;
      expect(path, startsWith('assets/covers/'),
          reason: '${song.title} should use the bundled asset');
      if (!shipped.contains(path)) missing.add('${song.title}: $path');
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('cover art is found by the same name as the audio', () async {
    // One name finds a song's MP3, its ground truth and its art. Keeping
    // that true is what makes adding a song three files and one line.
    for (final song in SongCatalogService.bundled) {
      expect(song.imagePath, 'assets/covers/${song.assetName}.jpg',
          reason: song.title);
    }
  });

  test('the covers actually decode', () async {
    // Present in the manifest is not the same as being a usable image: a
    // truncated or mislabelled file passes the first test and fails on a
    // user's screen.
    for (final song in SongCatalogService.bundled) {
      final data = await rootBundle.load(song.imagePath);
      expect(data.lengthInBytes, greaterThan(1000),
          reason: '${song.title} is suspiciously small');
      final bytes = data.buffer.asUint8List();
      // JPEG magic number.
      expect(bytes[0], 0xFF, reason: '${song.title} is not a JPEG');
      expect(bytes[1], 0xD8, reason: '${song.title} is not a JPEG');
    }
  });

  test('no song carries a remote URL any more', () {
    for (final song in SongCatalogService.bundled) {
      expect(song.imagePath, isNot(startsWith('http')),
          reason: '${song.title} would need a connection to show its art');
    }
  });

  test('the catalog map hands on the asset path', () {
    for (final entry in SongCatalogService.bundledSongs) {
      expect(entry['image'], startsWith('assets/covers/'),
          reason: entry['title']);
    }
  });

  group('the widget copes with every source it is given', () {
    Future<void> pump(WidgetTester tester, String image) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SongCoverArt(image: image))),
      ));
      await tester.pump();
    }

    testWidgets('a bundled asset', (tester) async {
      await pump(tester, SongCatalogService.bundled.first.imagePath);
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('an empty string falls back rather than throwing',
        (tester) async {
      await pump(tester, '');
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('a missing asset falls back', (tester) async {
      await pump(tester, 'assets/covers/Not A Song - Nobody.jpg');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a URL is still accepted, for an admin-added song',
        (tester) async {
      // Search & Sing results and admin uploads are not bundled, so the
      // widget cannot assume everything is local.
      await pump(tester, 'https://example.invalid/cover.jpg');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a device file path is accepted too', (tester) async {
      await pump(tester, '/data/user/0/app/files/cover.jpg');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it honours an explicit width and height', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SongCoverArt(image: '', width: 120, height: 60),
          ),
        ),
      ));
      expect(tester.getSize(find.byType(SongCoverArt)),
          const Size(120, 60));
    });
  });
}
