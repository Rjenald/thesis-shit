import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'karaoke_recording_page.dart';

/// Karaoke Practice Mode — student intro view with instruction and assignment.
/// Matches Figma design for Lesson 2: Karaoke Practice
class KaraokePracticeModePage extends StatelessWidget {
  final Map<String, dynamic> classData;
  final String songTitle;
  final String songArtist;
  final String songImage;
  final DateTime? dueDate;
  final int maxScore;

  const KaraokePracticeModePage({
    Key? key,
    required this.classData,
    required this.songTitle,
    required this.songArtist,
    required this.songImage,
    this.dueDate,
    this.maxScore = 100,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final className = classData['name'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Column(
        children: [
          // ── Cyan header ──────────────────────────────────────────────
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
                Row(children: [
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
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    'Lesson 2: Karaoke Practice',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instruction section
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5A5A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Instruction:',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Song button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KaraokeRecordingPage(
                            songTitle: songTitle,
                            songArtist: songArtist,
                            songImage: songImage,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Text(
                              'Song: $songTitle',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Sing',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Assignment section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assignment',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Max Score:',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontFamily: 'Roboto',
                              ),
                            ),
                            Text(
                              '$maxScore',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Deadline:',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontFamily: 'Roboto',
                              ),
                            ),
                            Text(
                              'March 21',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ],
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
      bottomNavigationBar: _buildBottomNav(context),
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
