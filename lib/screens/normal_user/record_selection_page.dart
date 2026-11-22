import 'package:final_thesis_ui/screens/normal_user/freestyle_recording_page.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'search_and_sing_page.dart';
import 'karaoke_song_catalog_page.dart';

class RecordSelectionPage extends StatelessWidget {
  const RecordSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Record',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            // Center Content
            //
            // Scrollable rather than a plain Center: the heading plus the
            // three mode buttons are taller than a 320x568 handset can
            // show, and a Column inside an Expanded clips what does not
            // fit — the third mode was unreachable on a small phone.
            // SliverFillRemaining keeps it centred when it does fit.
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Record',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Scored — songs with an authored reference melody, so
                      // the result can compare target vs actual pitch.
                      _ModeButton(
                        icon: Icons.emoji_events_outlined,
                        title: 'Scored Karaoke',
                        subtitle: 'Sing a prepared song and get pitch scoring',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KaraokeSongCatalogPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search & Sing — any song found online; no reference melody
                      // exists for it, so the result analyses what was sung
                      // instead of scoring it against a target.
                      _ModeButton(
                        icon: Icons.search,
                        title: 'Search & Sing',
                        subtitle: 'Find any song online and sing along',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchAndSingPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _ModeButton(
                        icon: Icons.mic_none,
                        title: 'Freestyle Karaoke',
                        subtitle: 'Just sing — no song, no backing track',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FreestyleRecordingPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(currentIndex: 2),
    );
  }
}

/// One of the three singing modes: an icon, the mode's name, and a line
/// saying what it actually does — the three differ in whether there's a
/// reference melody and a backing track, which isn't obvious from the names
/// alone.
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.inputBg,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppColors.primaryCyan, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'Roboto',
                      height: 1.3,
                      color: AppColors.grey.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.grey.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
