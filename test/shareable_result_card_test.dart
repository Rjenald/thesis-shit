import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:final_thesis_ui/services/result_share_service.dart';
import 'package:final_thesis_ui/widgets/shareable_result_card.dart';

/// The card is what gets shared, so the failures worth catching are the
/// quiet ones: a blank capture, a card that invents a score it has no
/// basis for, or text that overflows out of the picture.
void main() {
  Future<void> pump(WidgetTester tester, Widget card,
      {GlobalKey? boundaryKey}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: card,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final scored = ShareableResultCard(
    songTitle: 'Nasa Iyo Na Ang Lahat',
    songArtist: 'Daniel Padilla',
    completedAt: DateTime(2026, 3, 14),
    score: 82,
    scoreLabel: 'Good',
    stats: const [
      ShareStat('On pitch', '18/22'),
      ShareStat('Off pitch', '4'),
      ShareStat('Duration', '3:41'),
    ],
  );

  final unscored = ShareableResultCard(
    songTitle: 'Freestyle',
    songArtist: '',
    completedAt: DateTime(2026, 3, 14),
    excerpt: 'mahal kita hanggang sa huli',
    stats: const [
      ShareStat('Words', '27'),
      ShareStat('Notes', '9'),
      ShareStat('Duration', '0:42'),
    ],
  );

  group('scored card', () {
    testWidgets('leads with the score and shows the song', (tester) async {
      await pump(tester, scored);

      expect(find.text('82'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Nasa Iyo Na Ang Lahat'), findsOneWidget);
      expect(find.text('Daniel Padilla'), findsOneWidget);
      expect(find.text('18/22'), findsOneWidget);
      expect(find.text('SCORED KARAOKE'), findsOneWidget);
    });

    test('score colour tracks the same bands the results screen uses', () {
      Color accent(double s) => ShareableResultCard(
            songTitle: 't',
            songArtist: 'a',
            completedAt: DateTime(2026, 1, 1),
            score: s,
          ).accentForTest;

      expect(accent(95), const Color(0xFF4CAF50));
      expect(accent(80), const Color(0xFF4CAF50), reason: 'boundary');
      expect(accent(79), const Color(0xFFFF9800));
      expect(accent(60), const Color(0xFFFF9800), reason: 'boundary');
      expect(accent(59), const Color(0xFFFF5252));
      expect(accent(0), const Color(0xFFFF5252));
    });
  });

  group('unscored card', () {
    testWidgets('shows no score at all', (tester) async {
      await pump(tester, unscored);

      // The point of the separate layout: a reference-free take has no
      // target to score against, so no number may appear.
      expect(find.text('%'), findsNothing);
      expect(find.text('VOICE ANALYSIS'), findsOneWidget);
      expect(find.text('I just sang this'), findsOneWidget);
      expect(find.text('mahal kita hanggang sa huli'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
    });

    testWidgets('omits the artist line when there is none', (tester) async {
      await pump(tester, unscored);
      expect(find.text(''), findsNothing);
    });

    testWidgets('omits the excerpt block when there is no excerpt',
        (tester) async {
      await pump(
        tester,
        ShareableResultCard(
          songTitle: 'Freestyle',
          songArtist: '',
          completedAt: DateTime(2026, 3, 14),
          stats: const [ShareStat('Words', '0')],
        ),
      );
      expect(find.byType(ShareableResultCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout holds', () {
    testWidgets('a very long title and artist do not overflow',
        (tester) async {
      await pump(
        tester,
        ShareableResultCard(
          songTitle: 'A Song Title That Is Unreasonably Long And Keeps '
              'Going Well Past Any Sensible Length For A Card',
          songArtist: 'An Artist With An Equally Unreasonable Name '
              'That Also Refuses To Stop',
          completedAt: DateTime(2026, 3, 14),
          score: 100,
          scoreLabel: 'Needs work',
          excerpt: 'a transcription that rambles on and on and on well '
              'beyond what two lines could ever hold on a shared card',
          stats: const [
            ShareStat('Something long', '100/100'),
            ShareStat('Another', '1234'),
            ShareStat('Duration', '12:34'),
          ],
        ),
      );
      // An overflow is reported as an exception by the test binding, so
      // this is what proves the ellipsising actually works.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a huge system font scale cannot reflow the card',
        (tester) async {
      // The card pins textScaler internally; without that, a user's
      // accessibility setting would change the shared image's layout.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
            child: Scaffold(body: Center(child: scored)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final size = tester.getSize(find.byType(ShareableResultCard));
      expect(size.width, ShareableResultCard.width);
      expect(size.height, ShareableResultCard.height);
    });

    testWidgets('renders at its declared fixed size', (tester) async {
      await pump(tester, scored);
      final size = tester.getSize(find.byType(ShareableResultCard));
      expect(size, const Size(ShareableResultCard.width,
          ShareableResultCard.height));
    });
  });

  group('capture', () {
    testWidgets('produces real PNG bytes, not a blank', (tester) async {
      final key = GlobalKey();
      await pump(tester, scored, boundaryKey: key);

      // runAsync, because toImage needs the real rasterizer: under the
      // test binding's fake clock it simply never completes.
      final png = await tester.runAsync(
        () => ResultShareService.capture(key),
      );

      expect(png, isNotNull);
      // PNG magic number: a truncated or empty capture fails this.
      expect(png!.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      // A card this size at pixelRatio 3 is never a few hundred bytes; a
      // fully blank image would compress to almost nothing.
      expect(png.length, greaterThan(5000));
    });

    testWidgets('returns null rather than throwing on an unmounted key',
        (tester) async {
      // Callers treat null as "try again"; an exception here would crash
      // the share sheet instead.
      final orphan = GlobalKey();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(await ResultShareService.capture(orphan), isNull);
    });
  });
}
