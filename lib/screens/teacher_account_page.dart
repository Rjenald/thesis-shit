import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/session_storage_service.dart';
import 'home_page.dart';
import 'piano_mode_page.dart';
import 'practice_drill_page.dart';
import 'teacher_mode_page.dart';
import 'welcome_screen.dart';

class TeacherAccountPage extends StatefulWidget {
  const TeacherAccountPage({super.key});

  @override
  State<TeacherAccountPage> createState() => _TeacherAccountPageState();
}

class _TeacherAccountPageState extends State<TeacherAccountPage> {
  String _username = 'Teacher';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await SessionStorageService.loadUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _username = name);
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Logout',
            style: TextStyle(color: AppColors.white, fontFamily: 'Roboto')),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: AppColors.grey, fontFamily: 'Roboto')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout',
                style: TextStyle(
                    color: Color(0xFFF44336), fontFamily: 'Roboto')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryCyan.withValues(alpha: 0.18),
                            AppColors.primaryCyan.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                AppColors.primaryCyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                AppColors.primaryCyan.withValues(alpha: 0.2),
                            child: Text(
                              _username.isNotEmpty
                                  ? _username[0].toUpperCase()
                                  : 'T',
                              style: const TextStyle(
                                  color: AppColors.primaryCyan,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, $_username',
                                  style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Roboto'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCyan
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.school,
                                          size: 11,
                                          color: AppColors.primaryCyan),
                                      SizedBox(width: 4),
                                      Text('Teacher Account',
                                          style: TextStyle(
                                              color: AppColors.primaryCyan,
                                              fontSize: 11,
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Section label
                    const Text(
                      'TEACHER TOOLS',
                      style: TextStyle(
                        color: AppColors.primaryCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Practice Drills card
                    _ToolCard(
                      icon: Icons.fitness_center_outlined,
                      title: 'Practice Drills',
                      subtitle:
                          'Scale exercises, sustained notes,\nand phrase loop drills',
                      color: AppColors.primaryCyan,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PracticeDrillPage()),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Teacher Mode card
                    _ToolCard(
                      icon: Icons.class_outlined,
                      title: 'Teacher Mode',
                      subtitle:
                          'Manage classes, assign songs,\nand view student reports',
                      color: const Color(0xFF7C4DFF),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TeacherModePage()),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Piano Mode card
                    _ToolCard(
                      icon: Icons.piano_outlined,
                      title: 'Piano Mode',
                      subtitle:
                          'Play piano keys, record sequences,\nand have students follow along',
                      color: const Color(0xFFFF6D00),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PianoModePage()),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Divider with label
                    Row(children: [
                      Expanded(
                          child: Divider(
                              color: AppColors.grey.withValues(alpha: 0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('KARAOKE',
                            style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.5),
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontFamily: 'Roboto')),
                      ),
                      Expanded(
                          child: Divider(
                              color: AppColors.grey.withValues(alpha: 0.2))),
                    ]),

                    const SizedBox(height: 14),

                    // Go to Karaoke button
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const HomePage(showBackButton: true)),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.inputBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic_none_outlined,
                                color: AppColors.grey, size: 26),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Open Karaoke',
                                      style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Roboto')),
                                  SizedBox(height: 2),
                                  Text('Browse songs and start singing',
                                      style: TextStyle(
                                          color: AppColors.grey,
                                          fontSize: 12,
                                          fontFamily: 'Roboto')),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.grey.withValues(alpha: 0.5),
                                size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.school, color: AppColors.primaryCyan, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Teacher Account',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout,
                color: Color(0xFFF44336), size: 22),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontFamily: 'Roboto',
                          height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: color.withValues(alpha: 0.6), size: 16),
          ],
        ),
      ),
    );
  }
}
