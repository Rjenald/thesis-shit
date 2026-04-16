import 'package:final_thesis_ui/screens/solfagepitch_page.dart';
import 'package:final_thesis_ui/screens/voice_classification_page.dart';
import 'package:final_thesis_ui/screens/practice_drill_page.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';

class EducationModePage extends StatelessWidget {
  const EducationModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.school,
                        color: AppColors.primaryCyan, size: 72),
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
                      'Huni Learning Modules',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 40),

                    _EduButton(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Voice Classification',
                      subtitle: 'Identify your voice type',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const VoiceClassificationPage()),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _EduButton(
                      icon: Icons.music_note_outlined,
                      title: 'Solfège Pitch',
                      subtitle: 'Do-Re-Mi pitch matching',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SolfegePitchPage()),
                      ),
                    ),
                    const SizedBox(height: 14),

                    _EduButton(
                      icon: Icons.fitness_center_outlined,
                      title: 'Practice Drills',
                      subtitle: 'Scale, sustain & phrase exercises',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PracticeDrillPage()),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vocal health alerts in this app are heuristic and non-diagnostic. '
                              'Consult a licensed vocal coach or ENT specialist for medical advice.',
                              style: TextStyle(
                                  color:
                                      Colors.amber.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontFamily: 'Roboto',
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            BottomNavBar(
              currentIndex: 3,
              onTap: (index) {
                if (index != 3) Navigator.pop(context);
              },
            ),
          ],
        ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                  Text(title,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.grey.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
