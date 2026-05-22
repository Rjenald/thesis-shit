import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../normal_user/solfagepitch_page.dart';
import 'create_solfege_drill_page.dart';
import '../student/solfege_activity_page.dart';
import 'task_performance_assign_page.dart';

class TeacherEducationModePage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final String lessonTitle;

  const TeacherEducationModePage({
    super.key,
    required this.classData,
    required this.lessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    final className = classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // Teal header
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
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '$lessonTitle  /  Education Mode',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body — education mode layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.school,
                    color: AppColors.primaryCyan,
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EDUCATION MODE',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Assign learning modules to your class',
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Solfege Drill
                  _EduButton(
                    icon: Icons.music_note_outlined,
                    title: 'Solfege Drill',
                    subtitle: 'Create & preview solfege drill sequences',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateSolfegeDrillPage(
                          classData: classData,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Solfege Activity
                  _EduButton(
                    icon: Icons.queue_music_outlined,
                    title: 'Solfege Activity',
                    subtitle: 'Assign solfege note-matching to students',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SolfegeActivityPage(
                          classData: classData,
                          lessonTitle: lessonTitle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Task Performance
                  _EduButton(
                    icon: Icons.assignment_outlined,
                    title: 'Task Performance',
                    subtitle: 'Assign performance tasks with scoring',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskPerformanceAssignPage(
                          classData: classData,
                          lessonTitle: lessonTitle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Solfege Pitch
                  _EduButton(
                    icon: Icons.graphic_eq_outlined,
                    title: 'Solfège Pitch',
                    subtitle: 'Do-Re-Mi pitch matching & detection',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SolfegePitchPage(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primaryCyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primaryCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Activities you assign here will be sent as notifications '
                            'to all enrolled students in $className.',
                            style: TextStyle(
                              color: AppColors.primaryCyan.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 11,
                              fontFamily: 'Roboto',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EduButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EduButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.grey, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.grey.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
