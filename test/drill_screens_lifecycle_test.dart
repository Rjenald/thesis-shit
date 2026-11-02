import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/screens/normal_user/solfagepitch_page.dart';
import 'package:final_thesis_ui/screens/normal_user/voice_classification_page.dart';

/// Opening a drill screen and leaving it again.
///
/// A real device threw `'_dependents.isEmpty': is not true` from
/// framework.dart while the drills were being tested — an element torn
/// down while something still depended on it. That is a teardown-order
/// problem, so it only shows up when a screen is actually disposed, which
/// nothing in the suite was doing.
void main() {
  /// A phone-shaped viewport. The 800x600 default is shorter than any
  /// handset, and these screens overflow in it — which has nothing to do
  /// with the teardown bug and would mask it.
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openAndLeave(
    WidgetTester tester,
    Widget screen, {
    Duration settle = const Duration(milliseconds: 400),
  }) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
    await tester.pump(settle);
    // Replace the whole tree: the same thing popping the route does, and
    // the moment the assertion fired.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the solfège drill opens and closes cleanly', (tester) async {
    await openAndLeave(tester, const SolfegePitchPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the voice-classification drill opens and closes cleanly',
      (tester) async {
    await openAndLeave(tester, const VoiceClassificationPage());
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving immediately, before anything has settled',
      (tester) async {
    usePhoneViewport(tester);
    // The piano's sound pool loads off the first frame, so leaving at
    // once tears down mid-load.
    await tester.pumpWidget(const MaterialApp(home: SolfegePitchPage()));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening and closing repeatedly', (tester) async {
    for (var i = 0; i < 3; i++) {
      await openAndLeave(tester, const SolfegePitchPage(),
          settle: const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull, reason: 'cycle $i');
    }
  });
}
