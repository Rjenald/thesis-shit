import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'lesson_detail_page.dart';

/// Class detail page â€” shows lesson list and "View Students" button.
/// Header is full-width teal/cyan matching Figma design.
class ClassDetailPage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final int classIndex;
  final VoidCallback onClassUpdated;

  const ClassDetailPage({
    super.key,
    required this.classData,
    required this.classIndex,
    required this.onClassUpdated,
  });

  static const _lessons = [
    {
      'number': 1,
      'title': 'Solfege Drill',
      'subtitle': 'Basic scale exercises and note recognition',
    },
    {
      'number': 2,
      'title': 'Karaoke Practice',
      'subtitle': 'Song performance with pitch tracking',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final className = classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // â”€â”€ Teal full-width header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            width: double.infinity,
            color: AppColors.primaryCyan,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 22,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    className.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Lesson cards
                ..._lessons.map((l) => _buildLessonCard(l)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildLessonCard(Map<String, Object> lesson) {
    final number = lesson['number'] as int;
    final title = lesson['title'] as String;

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonDetailPage(
              classData: classData,
              lessonNumber: number,
              lessonTitle: title,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Lesson $number: $title',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      ),
    );
  }

  // â”€â”€ Bottom nav â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 70,
      color: AppColors.bottomNavBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navIcon(Icons.notifications_outlined),
          _navIcon(Icons.home_outlined, onTap: () => Navigator.pop(context)),
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
        child: Icon(
          icon,
          color: AppColors.grey.withValues(alpha: 0.5),
          size: 26,
        ),
      ),
    );
  }
}
