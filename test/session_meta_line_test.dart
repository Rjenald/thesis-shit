import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/screens/normal_user/library_page.dart';

/// The library card's date-and-badges line, which used to overflow.
///
/// A take that was *both* flat and sharp put a date and two badges in a
/// [Row] where nothing could yield, overflowing the card by 41 logical
/// pixels and painting the striped overflow banner across the list.
///
/// Flutter reports an overflow as a real exception during layout, so
/// these tests do not need to measure pixels: they pump the line into the
/// width it actually gets and assert that nothing was thrown. That is why
/// the widget was pulled out of the private row builder — the part that
/// broke is now the part that is tested.
void main() {
  /// Roughly what the line is given inside a card: a 56px thumbnail, a
  /// score pill and two icon buttons all come out of the row first.
  const availableWidth = 150.0;

  Future<void> pump(
    WidgetTester tester, {
    required bool flat,
    required bool sharp,
    String date = '11-02-2026  18:55',
    double width = availableWidth,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Center(
            child: SizedBox(
              width: width,
              child: SessionMetaLine(
                dateText: date,
                flat: flat,
                sharp: sharp,
              ),
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('both badges at once do not overflow', (tester) async {
    await pump(tester, flat: true, sharp: true);
    expect(tester.takeException(), isNull,
        reason: 'a take that was both flat and sharp overflowed the card '
            'by 41px before this line became a Wrap');
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Sharp'), findsOneWidget);
  });

  testWidgets('one badge does not overflow', (tester) async {
    await pump(tester, flat: true, sharp: false);
    expect(tester.takeException(), isNull);
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Sharp'), findsNothing);

    await pump(tester, flat: false, sharp: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Flat'), findsNothing);
    expect(find.text('Sharp'), findsOneWidget);
  });

  testWidgets('no badge shows just the date', (tester) async {
    await pump(tester, flat: false, sharp: false);
    expect(tester.takeException(), isNull);
    expect(find.text('11-02-2026  18:55'), findsOneWidget);
    expect(find.text('Flat'), findsNothing);
    expect(find.text('Sharp'), findsNothing);
  });

  testWidgets('it survives a cramped card', (tester) async {
    // The width is not something this widget controls: a long song title
    // or a 3-digit score takes space from the same row.
    for (final width in [90.0, 110.0, 130.0, 150.0, 200.0, 320.0]) {
      await pump(tester, flat: true, sharp: true, width: width);
      expect(tester.takeException(), isNull,
          reason: 'overflowed at ${width}px wide');
    }
  });

  testWidgets('it survives a large system text scale', (tester) async {
    // Accessibility text scaling grows the date and both badges at once,
    // which is the same squeeze from the other direction.
    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      await pump(tester, flat: true, sharp: true, textScale: scale);
      expect(tester.takeException(), isNull,
          reason: 'overflowed at ${scale}x text scale');
    }
  });

  testWidgets('badges drop to a second line rather than overflowing',
      (tester) async {
    // The mechanism, not just the absence of a crash: at a width that
    // cannot hold the date and both badges side by side, the line must
    // get taller instead of wider.
    await pump(tester, flat: true, sharp: true, width: 320);
    final wide = tester.getSize(find.byType(SessionMetaLine)).height;
    await pump(tester, flat: true, sharp: true, width: 90);
    final narrow = tester.getSize(find.byType(SessionMetaLine)).height;
    expect(tester.takeException(), isNull);
    expect(narrow, greaterThan(wide),
        reason: 'the badges should have wrapped onto another line');
  });

  testWidgets('a long date does not overflow either', (tester) async {
    // Date formatting follows the device locale, so its width is not
    // fixed by this screen.
    await pump(tester, flat: true, sharp: true,
        date: 'Wednesday, 12 November 2026  18:55:42');
    expect(tester.takeException(), isNull);
  });
}
