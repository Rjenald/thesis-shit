import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:final_thesis_ui/services/profile_picture_service.dart';
import 'package:final_thesis_ui/widgets/bottom_nav_bar.dart';
import 'package:final_thesis_ui/screens/normal_user/education_mode_page.dart';
import 'package:final_thesis_ui/screens/normal_user/library_page.dart';
import 'package:final_thesis_ui/screens/normal_user/record_selection_page.dart';

/// The four-tab bar.
///
/// It used to take a required `onTap` and never call it. Eight screens
/// passed one anyway: six wrote out a routing method that could not run,
/// and two passed `(_) {}`. Nothing was broken on screen — the bar has
/// always navigated by itself — but the dead handlers read as the thing
/// doing the navigating, so anyone changing where a tab goes would have
/// edited six methods and seen no change at all.
///
/// These tests pin what the bar actually does, now that the parameter is
/// gone and there is nothing left suggesting otherwise.
void main() {
  Future<void> pumpBar(WidgetTester tester, int currentIndex) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => ProfilePictureService(),
      child: MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomNavBar(currentIndex: currentIndex),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('all four tabs are shown', (tester) async {
    await pumpBar(tester, 0);
    for (final label in ['Home', 'Library', 'Record', 'Training']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('tapping a tab navigates', (tester) async {
    await pumpBar(tester, 0);
    await tester.tap(find.text('Library'));
    // Pumped rather than settled: LibraryPage shows a spinner while it
    // waits on storage, which never arrives in a widget test, so
    // pumpAndSettle would wait for an animation that never stops.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('Record and Training go where they say', (tester) async {
    await pumpBar(tester, 0);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(RecordSelectionPage), findsOneWidget);

    await pumpBar(tester, 0);
    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(EducationModePage), findsOneWidget);
  });

  testWidgets('tapping the tab you are already on does nothing',
      (tester) async {
    // Without the guard this pushes a second copy of the screen, and Back
    // then appears to do nothing.
    await pumpBar(tester, 1);
    await tester.tap(find.text('Library'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LibraryPage), findsNothing);
  });

  testWidgets('the whole tab is tappable, not just the word',
      (tester) async {
    // The label was the entire hit target, so "Home" was a much smaller
    // button than "Training". Tapping the icon above the word should
    // work too.
    await pumpBar(tester, 0);
    await tester.tap(find.byIcon(Icons.library_music));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('each tab gets an equal quarter of the bar', (tester) async {
    // Equal widths are what keeps the labels from overflowing at a larger
    // system font size, so this is load-bearing rather than cosmetic.
    await pumpBar(tester, 0);
    final widths = <double>[];
    for (final label in ['Home', 'Library', 'Record', 'Training']) {
      widths.add(tester
          .getSize(find
              .ancestor(
                  of: find.text(label), matching: find.byType(GestureDetector))
              .first)
          .width);
    }
    for (final w in widths) {
      expect((w - widths.first).abs(), lessThan(1.0),
          reason: 'tab widths were $widths');
    }
  });
}
