import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/class_notification.dart';
import '../services/session_storage_service.dart';
import '../services/class_notifications_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'notifications_page.dart';
import 'solfege_drill_mode_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  String _username = 'Student';
  bool _isMenuOpen = false;

  static const List<StudentLesson> _defaultLessons = [
    StudentLesson(
      id: '1',
      title: 'Solfege Drill',
      icon: Icons.music_note,
      sequence: ['Do', 'Re', 'Mi', 'Fa'],
      isCompleted: false,
    ),
    StudentLesson(
      id: '2',
      title: 'Karaoke Practice',
      icon: Icons.mic,
      sequence: [],
      isCompleted: false,
    ),
    StudentLesson(
      id: '3',
      title: 'Piano-Voice Matching',
      icon: Icons.piano,
      sequence: [],
      isCompleted: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeNotifications();
  }

  Future<void> _loadUserData() async {
    final name = await SessionStorageService.loadUsername();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _username = name);
    }
  }

  Future<void> _initializeNotifications() async {
    final service = ClassNotificationsService();
    await service.initialize();
  }

  List<StudentClass> _deriveEnrolledClasses(ClassNotificationsService service) {
    final accepted = service.notifications
        .where(
          (n) => n.type == NotificationType.enrollmentRequest && n.isAccepted,
        )
        .toList();

    return accepted.map((n) {
      return StudentClass(
        id: n.id,
        name: n.className,
        teacher: n.teacherName,
        grade: n.className,
        lessons: _defaultLessons,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Classroom',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          Text(
                            'Welcome, $_username',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.grey.withValues(alpha: 0.7),
                              fontFamily: 'Roboto',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsPage(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.notifications_outlined,
                                    color: AppColors.grey,
                                    size: 24,
                                  ),
                                  Consumer<ClassNotificationsService>(
                                    builder: (context, service, child) {
                                      final unread = service.unreadCount;
                                      if (unread > 0) {
                                        return Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                unread > 9
                                                    ? '9+'
                                                    : unread.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Roboto',
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isMenuOpen = !_isMenuOpen),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.inputBg,
                              child: Text(
                                _username.isNotEmpty
                                    ? _username[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: AppColors.primaryCyan,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Classroom Body
                Expanded(
                  child: Consumer<ClassNotificationsService>(
                    builder: (context, service, _) {
                      final enrolled = _deriveEnrolledClasses(service);
                      if (enrolled.isEmpty) {
                        return _buildNotEnrolledView();
                      }
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: enrolled.length,
                        itemBuilder: (context, index) =>
                            _buildClassroom(enrolled[index]),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Profile Menu Overlay
            if (_isMenuOpen)
              GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 70, right: 16),
                      child: Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.inputBg,
                                    child: Text(
                                      _username.isNotEmpty
                                          ? _username[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        color: AppColors.primaryCyan,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Roboto',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _username,
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                        Text(
                                          'Student',
                                          style: TextStyle(
                                            color: AppColors.grey.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 12,
                                            fontFamily: 'Roboto',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: AppColors.inputBg, height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.logout,
                                color: AppColors.errorRed,
                                size: 20,
                              ),
                              title: const Text(
                                'Logout',
                                style: TextStyle(
                                  color: AppColors.errorRed,
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                ),
                              ),
                              dense: true,
                              onTap: () async {
                                await SessionStorageService.clearStudentAccount();
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/start',
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // Navigation logic handled by BottomNavBar
        },
        isStudent: true,
      ),
    );
  }

  Widget _buildNotEnrolledView() {
    return Column(
      children: [
        // Cyan banner with "Not Enrolled yet"
        Container(
          width: double.infinity,
          color: AppColors.primaryCyan,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: const Center(
            child: Text(
              'Not Enrolled yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: AppColors.grey.withValues(alpha: 0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check your Notifications to confirm a class enrollment request from your teacher.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications),
                    label: const Text('Open Notifications'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassroom(StudentClass studentClass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cyan class banner
        Container(
          width: double.infinity,
          color: AppColors.primaryCyan,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text(
              studentClass.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
        // Plain lesson list
        ...List.generate(
          studentClass.lessons.length,
          (index) => _buildLessonRow(
            index + 1,
            studentClass.lessons[index],
            studentClass,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonRow(
    int lessonNumber,
    StudentLesson lesson,
    StudentClass studentClass,
  ) {
    return InkWell(
      onTap: () {
        if (lesson.title == 'Solfege Drill') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SolfegeDrillModePage(
                sequence: lesson.sequence,
                className: studentClass.name,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.inputBg.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Text(
          'Lesson $lessonNumber: ${lesson.title}',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }
}

class StudentClass {
  final String id;
  final String name;
  final String teacher;
  final String grade;
  final List<StudentLesson> lessons;

  const StudentClass({
    required this.id,
    required this.name,
    required this.teacher,
    required this.grade,
    required this.lessons,
  });
}

class StudentLesson {
  final String id;
  final String title;
  final IconData icon;
  final List<String> sequence;
  final bool isCompleted;

  const StudentLesson({
    required this.id,
    required this.title,
    required this.icon,
    required this.sequence,
    required this.isCompleted,
  });
}
