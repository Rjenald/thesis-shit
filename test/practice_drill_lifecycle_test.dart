import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/screens/normal_user/practice_drill_page.dart';

/// Switching between drills, and leaving the screen.
///
/// A device threw `'_dependents.isEmpty': is not true` from
/// framework.dart while the drills were being used — an element unmounted
/// while something still depended on it.
///
/// `_buildBody` swaps three stateful drills behind a `setState`, so
/// changing tab disposes one and mounts another. That is the teardown
/// path, and nothing in the suite exercised it: every other test builds a
/// screen and never takes it down again.
void main() {
  void usePhoneViewport(WidgetTester tester) {
    // The 800x600 default is shorter than any handset and overflows these
    // screens, which would mask whatever else is wrong.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the drill screen opens', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: PracticeDrillPage()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching between all three drills', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: PracticeDrillPage()));
    await tester.pump(const Duration(milliseconds: 200));

    // Each switch disposes the drill that was showing.
    for (final label in ['Sustain', 'Phrases', 'Scale', 'Phrases', 'Scale']) {
      final tab = find.text(label);
      if (tab.evaluate().isEmpty) continue;
      await tester.tap(tab.first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull,
          reason: 'switching to $label');
    }
  });

  testWidgets('leaving the screen while a drill is mounted', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: PracticeDrillPage()));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('popping the route, as the back button does', (tester) async {
    usePhoneViewport(tester);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PracticeDrillPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeDrillPage), findsOneWidget);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving immediately, before anything settles', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: PracticeDrillPage()));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
