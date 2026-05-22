import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../normal_user/solfagepitch_page.dart';
import 'karaoke_assign_page.dart';
import '../normal_user/karaoke_practice_mode_page.dart';
import 'karaoke_submissions_page.dart';
import '../student/practice_solfege_page.dart';
import '../student/solfege_activity_page.dart';
import 'task_performance_assign_page.dart';

/// Sub-lesson list for a given lesson inside a class.
/// Matches Figma: teal header (class name + lesson subtitle),
/// then a list of numbered sub-lesson cards.
///
/// [isTeacher] switches navigation targets and adds teacher-only buttons
/// such as "View Submissions".
class LessonDetailPage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final int lessonNumber;
  final String lessonTitle;

  /// Set to true when accessed from the teacher account page.
  final bool isTeacher;

  const LessonDetailPage({
    super.key,
    required this.classData,
    required this.lessonNumber,
    required this.lessonTitle,
    this.isTeacher = false,
  });

  // ── Sub-lesson definitions ─────────────────────────────────────────────────
  List<_SubLesson> get _subLessons {
    switch (lessonNumber) {
      case 1:
        return [
          _SubLesson('1.1', 'Practice Solfege'),
          _SubLesson('1.2', 'Solfege Activity'),
        ];
      case 2:
        return [_SubLesson('2.1', 'Practice Karaoke')];
      case 3:
        return [
          _SubLesson('3.1', 'Task Performance'),
        ];
      case 4:
        return [
          _SubLesson('4.1', 'Solfege Pitch'),
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
        if (isTeacher) {
          // Teacher → assignment page
          page = KaraokeAssignPage(
            classData: classData,
            lessonTitle: 'Lesson $lessonNumber: $lessonTitle',
            subLessonTitle: sub.title,
          );
        } else {
          // Student → practice mode page
          page = KaraokePracticeModePage(
            classData: classData,
            songTitle: 'Dadalhin',
            songArtist: 'Regine Velasquez',
            songImage: '',
            dueDate: DateTime.now().add(const Duration(days: 7)),
            maxScore: 100,
          );
        }
        break;
      case 'Task Performance':
        page = TaskPerformanceAssignPage(
          classData: classData,
          lessonTitle: 'Lesson $lessonNumber: $lessonTitle',
        );
        break;
      case 'Solfege Pitch':
        page = const SolfegePitchPage();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _viewSubmissions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KaraokeSubmissionsPage(
          classData: classData,
          lessonTitle: 'Lesson $lessonNumber: $lessonTitle',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black,
                        size: 20,
                      ),
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
              children: [
                ..._subLessons.map((s) => _buildCard(context, s)),

                // Teacher-only action buttons for Lesson 2 (Karaoke)
                if (isTeacher && lessonNumber == 2) ...[
                  const SizedBox(height: 12),
                  _buildViewSubmissionsBtn(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _SubLesson sub) {
    return GestureDetector(
      onTap: () => _navigate(context, sub),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF4A4A4A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${sub.number}  ${sub.title}',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  /// "View Submissions" button — teacher only.
  Widget _buildViewSubmissionsBtn(BuildContext context) {
    return GestureDetector(
      onTap: () => _viewSubmissions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryCyan.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.assignment_turned_in_outlined,
              color: AppColors.primaryCyan,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'View Submissions',
              style: TextStyle(
                color: AppColors.primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _SubLesson {
  final String number;
  final String title;
  const _SubLesson(this.number, this.title);
}
