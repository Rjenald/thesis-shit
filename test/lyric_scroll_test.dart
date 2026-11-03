import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/data/song_lyrics.dart';
import 'package:final_thesis_ui/services/lyrics_service.dart' show LrcLine;

/// Keeping the line being sung on screen.
///
/// The player scrolled to `index * 56.0 - 120.0`, assuming every lyric
/// line was exactly 56 logical pixels tall. The error is multiplied by the
/// line index, so a few pixels per line becomes hundreds by the middle of
/// a song: the view runs ahead of the singing and the highlighted line
/// leaves the top of the viewport. It reads as scrolling too fast, but it
/// is accumulated error, not speed.
///
/// These tests measure the premise with the app's real lyrics rather than
/// asserting it, because the whole question is whether 56 is a safe
/// number — and that depends on the actual text.
void main() {
  /// The lyric list as the player renders it: 18pt upcoming lines, 16pt
  /// past ones, centred, in a column with 24px side padding.
  Widget lyricList({
    required List<LrcLine> lyrics,
    required int current,
    required ScrollController controller,
    GlobalKey? currentKey,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ListView.builder(
            controller: controller,
            cacheExtent: 1200,
            padding:
                const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            itemCount: lyrics.length,
            itemBuilder: (ctx, i) {
              final isPast = i < current;
              return Padding(
                key: i == current ? currentKey : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  lyrics[i].text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isPast ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('real lyric lines are not all 56 pixels tall', (tester) async {
    // 360 logical pixels wide: an ordinary handset, where the long lines
    // in this catalogue wrap.
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lyrics = LocalSongLyrics.getLyrics('Pano')!;
    expect(lyrics.length, greaterThan(20),
        reason: 'guard: this test needs a long song');

    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        lyricList(lyrics: lyrics, current: 0, controller: controller));
    await tester.pump();

    // Measure the lines that are actually on screen.
    final heights = <double>[];
    for (var i = 0; i < lyrics.length; i++) {
      final finder = find.text(lyrics[i].text);
      if (finder.evaluate().isEmpty) continue;
      heights.add(tester.getSize(finder.first).height + 24); // + padding
    }
    expect(heights, isNotEmpty);

    final varies = heights.any((h) => (h - heights.first).abs() > 4);
    expect(varies || heights.any((h) => (h - 56).abs() > 8), isTrue,
        reason: 'measured ${heights.toSet().toList()} — if every line '
            'really were 56px the old estimate would have been fine');
  });

  testWidgets('the fixed estimate misses by more than a line height',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lyrics = LocalSongLyrics.getLyrics('Pano')!;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Scanned across the song rather than sampled at one line: the drift
    // is not monotonic, and near the end the clamp to maxScrollExtent
    // hides it by pinning the list to the bottom. One unlucky index would
    // have made this look fine.
    var worst = 0.0;
    var worstLine = -1;
    for (var target = 2; target < lyrics.length - 1; target++) {
      final key = GlobalKey();
      await tester.pumpWidget(lyricList(
        lyrics: lyrics,
        current: target,
        controller: controller,
        currentKey: key,
      ));
      await tester.pump();

      final estimated = (target * 56.0) - 120.0;
      controller.jumpTo(
          estimated.clamp(0.0, controller.position.maxScrollExtent));
      await tester.pump();

      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        // Not built at all: as wrong as it gets.
        worst = 9999;
        worstLine = target;
        break;
      }
      final mid = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
      final off = (mid - 300).abs();
      if (off > worst) {
        worst = off;
        worstLine = target;
      }
    }

    // ignore: avoid_print
    print('worst miss with the fixed estimate: ${worst.round()}px '
        'at line $worstLine of ${lyrics.length}');
    expect(worst, greaterThan(56),
        reason: 'worst miss was ${worst.round()}px at line $worstLine. If '
            'this ever drops below one line height, the fixed estimate '
            'was good enough and ensureVisible is unnecessary.');
  });

  testWidgets('ensureVisible centres the line whatever its height',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final lyrics = LocalSongLyrics.getLyrics('Pano')!;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    // Several lines through the song, including ones that wrap.
    for (final target in [3, 12, 25, lyrics.length - 4]) {
      final key = GlobalKey();
      await tester.pumpWidget(lyricList(
        lyrics: lyrics,
        current: target,
        controller: controller,
        currentKey: key,
      ));
      await tester.pump();

      final ctx = key.currentContext;
      if (ctx == null) {
        // Not built yet: the real code jumps roughly first, then measures
        // on the next tick. Reproduce that here.
        controller.jumpTo(((target * 56.0) - 300)
            .clamp(0.0, controller.position.maxScrollExtent));
        await tester.pump();
      }

      final ctx2 = key.currentContext;
      expect(ctx2, isNotNull, reason: 'line $target should be built');
      await Scrollable.ensureVisible(ctx2!, alignment: 0.5);
      await tester.pumpAndSettle();

      final box = ctx2.findRenderObject() as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero);
      final mid = topLeft.dy + box.size.height / 2;

      // Lines near the very start or end cannot be centred — there is not
      // enough list either side — so the requirement is that the line is
      // fully visible, and centred where centring is possible.
      expect(topLeft.dy, greaterThanOrEqualTo(-1),
          reason: 'line $target is above the viewport');
      expect(topLeft.dy + box.size.height, lessThanOrEqualTo(601),
          reason: 'line $target is below the viewport');
      final atExtreme = controller.offset <= 1 ||
          controller.offset >= controller.position.maxScrollExtent - 1;
      if (!atExtreme) {
        expect((mid - 300).abs(), lessThan(40),
            reason: 'line $target sat ${(mid - 300).round()}px off centre');
      }
    }
  });

  test('the player measures instead of estimating', () {
    // Source-level, because the drift measured above is only fixed if the
    // player actually asks the laid-out element where it is.
    final src =
        File('lib/screens/normal_user/song_player_page.dart')
            .readAsStringSync();
    expect(src, contains('Scrollable.ensureVisible'),
        reason: 'the scroller must measure the real line position');
    expect(src, contains('_currentLyricKey'),
        reason: 'the current line needs a key to be measurable');
    expect(src, contains('addPostFrameCallback'),
        reason: 'measuring before layout reads the previous line');
  });
}
