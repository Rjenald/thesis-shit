import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'karaoke_assign_page.dart';
import 'piano_voice_matching_page.dart';
import 'practice_solfege_page.dart';
import 'solfege_activity_page.dart';

/// Sub-lesson list for a given lesson inside a class.
/// Matches Figma: teal header (class name + lesson subtitle),
/// then a list of numbered sub-lesson cards.
class LessonDetailPage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final int lessonNumber;
  final String lessonTitle;

  const LessonDetailPage({
    super.key,
    required this.classData,
    required this.lessonNumber,
    required this.lessonTitle,
  });

  // ── Sub-lesson definitions per lesson ────────────────────────────────────
  List<_SubLesson> get _subLessons {
    switch (lessonNumber) {
      case 1:
        return [
          _SubLesson('1.1', 'Practice Solfege'),
          _SubLesson('1.2', 'Solfege Activity'),
        ];
      case 2:
        return [
          _SubLesson('2.1', 'Practice Karaoke'),
        ];
      case 3:
        return [
          _SubLesson('3.1', 'Piano-Voice Activity'),
        ];
      default:
        return [];
    }
  }

  void _navigate(BuildContext context, _SubLesson sub) {
    Widget page;
    switch (sub.title) {
      case 'Practice Solfege':
        page = PracticeSolfegePage(
          classData: classData,
          lessonTitle: lessonTitle,
        );
        break;
      case 'Solfege Activity':
        page = SolfegeActivityPage(
          classData: classData,
          lessonTitle: lessonTitle,
        );
        break;
      case 'Practice Karaoke':
        page = KaraokeAssignPage(
          classData: classData,
          lessonTitle: lessonTitle,
          subLessonTitle: sub.title,
        );
        break;
      case 'Piano-Voice Activity':
        page = PianoVoiceMatchingPage(
          classData: classData,
          lessonTitle: lessonTitle,
        );
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final className = classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // ── Teal header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primaryCyan,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        className.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto',
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    'Lesson $lessonNumber: $lessonTitle',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Sub-lesson list ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: _subLessons
                  .map((s) => _buildCard(context, s))
                  .toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildCard(BuildContext context, _SubLesson sub) {
    return GestureDetector(
      onTap: () => _navigate(context, sub),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              sub.number,
              style: const TextStyle(
                color: AppColors.primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                sub.title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.notifications_outlined),
          _navIcon(Icons.home_outlined,
              onTap: () => Navigator.pop(context)),
          _navIcon(Icons.person_outline),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon,
            color: AppColors.grey.withValues(alpha: 0.5), size: 26),
      ),
    );
  }
}

class _SubLesson {
  final String number;
  final String title;
  const _SubLesson(this.number, this.title);
}
