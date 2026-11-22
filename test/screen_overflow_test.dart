import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:final_thesis_ui/services/profile_picture_service.dart';

import 'package:final_thesis_ui/screens/admin/admin_page.dart';
import 'package:final_thesis_ui/screens/admin/transcription_eval_page.dart';
import 'package:final_thesis_ui/screens/normal_user/education_mode_page.dart';
import 'package:final_thesis_ui/screens/normal_user/favorites_page.dart';
import 'package:final_thesis_ui/screens/normal_user/home_page.dart';
import 'package:final_thesis_ui/screens/normal_user/karaoke_song_catalog_page.dart';
import 'package:final_thesis_ui/screens/normal_user/library_page.dart';
import 'package:final_thesis_ui/screens/normal_user/music_lessons_page.dart';
import 'package:final_thesis_ui/screens/normal_user/practice_drill_page.dart';
import 'package:final_thesis_ui/screens/normal_user/recently_deleted_page.dart';
import 'package:final_thesis_ui/screens/normal_user/record_selection_page.dart';
import 'package:final_thesis_ui/screens/normal_user/recorded_karaoke_page.dart';
import 'package:final_thesis_ui/screens/normal_user/save_record_page.dart';
import 'package:final_thesis_ui/screens/normal_user/search_and_sing_page.dart';
import 'package:final_thesis_ui/screens/normal_user/settings_page.dart';
import 'package:final_thesis_ui/screens/normal_user/solfagepitch_page.dart';
import 'package:final_thesis_ui/screens/normal_user/voice_classification_page.dart';
import 'package:final_thesis_ui/screens/shared/login_page.dart';
import 'package:final_thesis_ui/screens/shared/register_page.dart';
import 'package:final_thesis_ui/screens/shared/start_page.dart';

/// Does any screen overflow its viewport?
///
/// A RenderFlex overflow shows as the yellow-and-black stripes in debug and
/// as silently clipped content in release — so a screen that overflows only
/// on a handset smaller than the development phone ships looking broken to
/// whoever owns that handset, and nobody sees it in between.
///
/// Rather than reading twenty-five files hunting for a Row without an
/// Expanded, this pumps each screen at the sizes that actually matter and
/// reports what the framework says.
///
/// Two things this deliberately does NOT treat as findings. Plugin
/// failures — there is no mic, database or file system in a widget test —
/// are ignored, since the question is only whether the layout fits. And
/// the provider main.dart installs is installed here too: without it
/// `ProfileAvatar`'s Consumer throws, Flutter substitutes an ErrorWidget,
/// and that sizes itself to 100000px, which reads as a spectacular layout
/// bug on a screen whose layout is fine.
void main() {
  /// Logical sizes, each a real device class.
  ///
  /// 320x568 is the smallest Android phone still in use and the width the
  /// Material guidelines treat as the floor. 360x640 is the common budget
  /// handset. 411x914 is a current mid-range phone — included because a
  /// screen can also overflow by being too *tall* for its content when a
  /// Column was sized against a shorter viewport.
  const sizes = <String, Size>{
    'small 320x568': Size(320, 568),
    'budget 360x640': Size(360, 640),
    'modern 411x914': Size(411, 914),
  };

  /// Pumps [screen] at [size] and returns every overflow the framework
  /// reported, ignoring everything else.
  ///
  /// Each screen gets its own test rather than sharing one loop: an
  /// overflow raised while the previous screen was being torn down would
  /// otherwise be blamed on whichever screen happened to be pumped next.
  Future<List<String>> overflowsIn(
    WidgetTester tester,
    Widget Function() screen,
    Size size, {
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;

    final found = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      // "A RenderFlex overflowed by 42 pixels on the bottom." and the
      // RenderConstrainedBox variants all say "overflowed".
      if (text.contains('overflowed')) {
        // Report WHERE as well as by how much: the framework names the
        // offending widget and its source line, which is the whole point
        // of running this rather than reading the files.
        final where =
            RegExp(r'[A-Za-z]+:file:///\S+').firstMatch(details.toString());
        found.add('${text.split('\n').first}  at ${where?.group(0) ?? '?'}');
      }
    };

    try {
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => ProfilePictureService(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              // copyWith, not a bare MediaQueryData: replacing the whole
              // thing zeroes the viewport size and every screen then
              // "overflows" for a reason that has nothing to do with text.
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: screen(),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    } finally {
      FlutterError.onError = previous;
      // Exceptions the harness did record (plugin failures) are discarded
      // deliberately — see the note above.
      tester.takeException();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
    return found;
  }

  /// Every screen that can be built without route arguments.
  ///
  /// The four that need them — ResultsPage, SongPlayerPage,
  /// FreestyleRecordingPage and FreestyleResultsPage — are covered by
  /// their own tests; SplashScreen is excluded because it navigates away
  /// on a timer and has no content to overflow.
  final screens = <String, Widget Function()>{
    'StartPage': () => const StartPage(),
    'LoginPage': () => const LoginPage(),
    'RegisterPage': () => const RegisterPage(),
    'HomePage': () => const HomePage(),
    'LibraryPage': () => const LibraryPage(),
    'FavoritesPage': () => const FavoritesPage(),
    'SettingsPage': () => const SettingsPage(),
    'RecordSelectionPage': () => const RecordSelectionPage(),
    'SaveRecordPage': () => const SaveRecordPage(),
    'RecentlyDeletedPage': () => const RecentlyDeletedPage(),
    'RecordedKaraokePage': () => const RecordedKaraokePage(),
    'KaraokeSongCatalogPage': () => const KaraokeSongCatalogPage(),
    'SearchAndSingPage': () => const SearchAndSingPage(),
    'EducationModePage': () => const EducationModePage(),
    'MusicLessonsPage': () => const MusicLessonsPage(),
    'PracticeDrillPage': () => const PracticeDrillPage(),
    'SolfegePitchPage': () => const SolfegePitchPage(),
    'VoiceClassificationPage': () => const VoiceClassificationPage(),
    'AdminPage': () => const AdminPage(),
    'TranscriptionEvalPage': () => const TranscriptionEvalPage(),
  };

  for (final screen in screens.entries) {
    testWidgets('${screen.key} fits every handset', (tester) async {
      final broken = <String>[];
      for (final size in sizes.entries) {
        for (final f in await overflowsIn(tester, screen.value, size.value)) {
          broken.add('${size.key}: $f');
        }
      }
      // Android's display settings go past 1.3x, and a label that only
      // just fits at 1.0 is the usual casualty.
      for (final f in await overflowsIn(
          tester, screen.value, const Size(360, 640), textScale: 1.3)) {
        broken.add('360x640 at 1.3x text: $f');
      }
      expect(broken, isEmpty, reason: '\n${broken.join('\n')}');
    });
  }
}
