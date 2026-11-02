import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/note_utils.dart' show PitchFeedback;
import 'package:final_thesis_ui/models/singing_segment.dart';
import 'package:final_thesis_ui/widgets/pitch_timeline_view.dart';

/// What the results screen shows when there is no note-by-note comparison.
///
/// It used to show nothing at all — `SizedBox.shrink()` — so a take with no
/// reference melody looked exactly like one where the section had been
/// scrolled past. The singer was left reading a 23% score with no way to
/// know it had been produced a different way, from pitch steadiness rather
/// than from hitting this song's notes.
///
/// The two causes are not the same and the copy has to distinguish them:
/// the song ships no ground truth (ordinary — most don't yet), or it does
/// and this take's analysis produced nothing (something broke).
void main() {
  SingingSegment segment() => const SingingSegment(
        syllable: '',
        startTimeMs: 1000,
        endTimeMs: 1400,
        targetNote: 'C4',
        targetFrequency: 261.63,
        actualNote: 'C4',
        actualFrequency: 262.0,
        differenceCents: 2.0,
        status: PitchFeedback.correct,
        confidence: 0.9,
      );

  Future<void> pump(
    WidgetTester tester, {
    required List<SingingSegment> segments,
    String? reason,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PitchTimelineView(segments: segments, emptyReason: reason),
        ),
      ),
    ));
  }

  testWidgets('with no segments and no reason, it stays silent',
      (tester) async {
    await pump(tester, segments: const []);
    expect(find.text('Pitch Timeline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no segments it explains itself rather than vanishing',
      (tester) async {
    await pump(tester, segments: const [], reason: 'No reference melody '
        'has been added for this song yet.');
    // The heading has to be there: an explanation floating with no title
    // reads as an error about something else on the screen.
    expect(find.text('Pitch Timeline'), findsOneWidget);
    expect(
        find.textContaining('No reference melody'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long explanation does not overflow', (tester) async {
    await pump(tester, segments: const [], reason:
        'No reference melody has been added for this song yet, so there '
        'is nothing to compare each note against. The score above comes '
        'from how steady your pitch was, not from whether you hit this '
        "song's notes.");
    expect(tester.takeException(), isNull);
  });

  testWidgets('with segments, the reason is ignored and the timeline shows',
      (tester) async {
    await pump(tester, segments: [segment()], reason: 'should not appear');
    expect(find.text('Pitch Timeline'), findsOneWidget);
    expect(find.text('should not appear'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it survives a narrow screen and large text', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: PitchTimelineView(
                segments: const [],
                emptyReason: 'No reference melody has been added for this '
                    'song yet, so there is nothing to compare each note '
                    'against.',
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull,
          reason: 'overflowed at ${scale}x text scale');
    }
  });
}
