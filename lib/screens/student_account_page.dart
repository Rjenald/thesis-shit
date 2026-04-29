import 'package:flutter/material.dart';
import '../data/tagalog_bisaya_songs.dart';
import 'karaoke_recording_page.dart';
import 'practice_solfege_page.dart';
import 'solfege_activity_page.dart';
import 'karaoke_practice_mode_page.dart';

const _cyan = Color(0xFF00ACC1);
const _dark = Colors.black;
const _cardBg = Color(0xFF3A3A3A);
const _navBg = Color(0xFF2A2A2A);

// ==================== MAIN NAV ====================

class StudentAccountPage extends StatefulWidget {
  const StudentAccountPage({super.key});

  @override
  State<StudentAccountPage> createState() => _StudentAccountPageState();
}

class _StudentAccountPageState extends State<StudentAccountPage> {
  int _selectedIndex = 0;

  // Enrollment state — becomes true when student confirms the enrollment notif
  bool _isEnrolled = false;
  final String _enrolledClass = 'Grade 11 – Sampaguita';

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onEnrollmentConfirmed() {
    setState(() {
      _isEnrolled = true;
      _selectedIndex = 2; // Jump to Home (Classroom)
    });
  }

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return NotificationScreen(onEnrollmentConfirmed: _onEnrollmentConfirmed);
      case 1:
        return const StudentKaraokeModeScreen();
      case 2:
        return ClassroomScreen(
          isEnrolled: _isEnrolled,
          className: _enrolledClass,
        );
      case 3:
        return const CalendarScreen();
      case 4:
        return const ProfileScreen();
      default:
        return ClassroomScreen(
          isEnrolled: _isEnrolled,
          className: _enrolledClass,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.notifications_outlined, 'Notification', 0),
                _buildNavItem(Icons.mic_none, 'Karaoke Mode', 1),
                _buildNavItem(Icons.home_outlined, 'Home', 2),
                _buildNavItem(Icons.calendar_today_outlined, 'Calendar', 3),
                _buildNavItem(Icons.person_outline, 'Profile', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? _cyan : Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? _cyan : Colors.white70,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== NOTIFICATION SCREEN ====================

class NotificationScreen extends StatefulWidget {
  final VoidCallback? onEnrollmentConfirmed;
  const NotificationScreen({super.key, this.onEnrollmentConfirmed});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'name': 'Bags, Kian Francis',
      'action': 'Add to Grade 11 – Sampaguita',
      'type': 'enrollment',
    },
    {
      'name': 'Bags, Kian Francis',
      'action': 'Added Activity | Solfege',
      'deadline': '01.01.21',
      'type': 'activity',
    },
  ];

  void _confirmNotification(int index) {
    final type = _notifications[index]['type'];
    setState(() => _notifications.removeAt(index));
    if (type == 'enrollment') {
      widget.onEnrollmentConfirmed?.call();
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Confirmed — you are now enrolled!'),
      backgroundColor: _cyan,
      duration: Duration(seconds: 2),
    ));
  }

  void _deleteNotification(int index) {
    setState(() => _notifications.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Notification deleted'),
      backgroundColor: Colors.redAccent,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        title: const Text('Notification',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Text('No new notifications',
                  style: TextStyle(color: Colors.white54, fontSize: 16)))
          : ListView.builder(
              itemCount: _notifications.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return _NotifCard(
                  name: n['name'],
                  action: n['action'],
                  deadline: n['deadline'],
                  type: n['type'],
                  onConfirm: () => _confirmNotification(index),
                  onDelete: () => _deleteNotification(index),
                );
              },
            ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final String name;
  final String action;
  final String? deadline;
  final String type;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const _NotifCard({
    required this.name,
    required this.action,
    this.deadline,
    required this.type,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      color: _navBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[700],
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(action,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (type == 'activity' && deadline != null)
            Text('Deadline: $deadline',
                style: const TextStyle(color: Colors.white54, fontSize: 11))
          else if (type == 'enrollment') ...[
            TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                foregroundColor: _cyan,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Confirm',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Delete',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== KARAOKE MODE SCREEN (same as normal user, no profile) ====================

class StudentKaraokeModeScreen extends StatefulWidget {
  const StudentKaraokeModeScreen({super.key});

  @override
  State<StudentKaraokeModeScreen> createState() =>
      _StudentKaraokeModeScreenState();
}

class _StudentKaraokeModeScreenState extends State<StudentKaraokeModeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedLanguage = 'All';

  List<KaraokeSong> get _filtered {
    final allSongs = TagalogBisayaSongs.songs;
    if (_query.trim().isEmpty && _selectedLanguage == 'All') return allSongs.toList();
    final q = _query.toLowerCase();
    return allSongs.where((s) {
      final matchesQuery = q.isEmpty ||
          s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q);
      final matchesLang =
          _selectedLanguage == 'All' || s.language == _selectedLanguage;
      return matchesQuery && matchesLang;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Header — NO profile icon
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Karaoke',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Roboto')),
                      Text('Choose a song to sing',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                              fontFamily: 'Roboto')),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note,
                            color: _cyan, size: 14),
                        const SizedBox(width: 4),
                        Text('${results.length} songs',
                            style: const TextStyle(
                                color: _cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search songs, artist...',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Language filter chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: ['All', 'Tagalog', 'Bisaya'].map((lang) {
                  final selected = _selectedLanguage == lang;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedLanguage = lang),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? _cyan
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(lang,
                          style: TextStyle(
                              color: selected ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Song list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final song = results[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KaraokeRecordingPage(
                          songTitle: song.title,
                          songArtist: song.artist,
                          songImage: '',
                        ),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.music_note,
                                color: Colors.white38, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(song.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(song.artist,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _cyan.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(song.language,
                                          style: const TextStyle(
                                              color: _cyan,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.play_circle_outline,
                              color: Colors.white38, size: 28),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CLASSROOM SCREEN ====================

class ClassroomScreen extends StatelessWidget {
  final bool isEnrolled;
  final String className;

  const ClassroomScreen({
    super.key,
    required this.isEnrolled,
    required this.className,
  });

  final List<Map<String, dynamic>> _lessons = const [
    {
      'title': 'Lesson 1: Solfege Drill',
      'subLessons': [
        {'number': '1.1', 'title': 'Practice Solfege'},
        {'number': '1.1', 'title': 'Solfege Activity'},
      ],
    },
    {
      'title': 'Lesson 2: Karaoke Practice',
      'subLessons': [
        {'number': '2.1', 'title': 'Karaoke Practice'},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        title: const Text('Classroom',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Cyan class banner
          Container(
            width: double.infinity,
            color: _cyan,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                isEnrolled ? className : 'Not Enrolled yet',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (isEnrolled)
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _lessons.length,
                itemBuilder: (context, index) {
                  final lesson = _lessons[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentLessonDetailPage(
                          className: className,
                          lessonTitle: lesson['title'],
                          subLessons: List<Map<String, dynamic>>.from(
                              lesson['subLessons']),
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _cardBg,
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.black.withValues(alpha: 0.3),
                              width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(lesson['title'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.white54, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Enroll in a class to see lessons',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== LESSON DETAIL PAGE ====================

class StudentLessonDetailPage extends StatelessWidget {
  final String className;
  final String lessonTitle;
  final List<Map<String, dynamic>> subLessons;

  const StudentLessonDetailPage({
    super.key,
    required this.className,
    required this.lessonTitle,
    required this.subLessons,
  });

  void _navigateToSubLesson(BuildContext context, String title) {
    final classData = {'name': className};
    Widget? page;

    switch (title) {
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
      case 'Karaoke Practice':
        page = KaraokePracticeModePage(
          classData: classData,
          songTitle: 'Dadalhin',
          songArtist: 'Regine Velasquez',
          songImage: '',
          dueDate: DateTime(2024, 3, 21),
          maxScore: 100,
        );
        break;
    }

    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // Cyan header
          Container(
            width: double.infinity,
            color: _cyan,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 18,
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(lessonTitle,
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Sub-lesson list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: subLessons.length,
              itemBuilder: (context, index) {
                final sub = subLessons[index];
                return GestureDetector(
                  onTap: () => _navigateToSubLesson(context, sub['title']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.black.withValues(alpha: 0.3),
                            width: 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Text(
                      '${sub['number']}    ${sub['title']}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        color: _navBg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navIcon(Icons.notifications_outlined),
            _navIcon(Icons.mic_none),
            _navIcon(Icons.home_outlined, onTap: () => Navigator.pop(context)),
            _navIcon(Icons.calendar_today_outlined),
            _navIcon(Icons.person_outline),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: Colors.white54, size: 26),
      ),
    );
  }
}

// ==================== PLACEHOLDER SCREENS ====================

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _dark,
      body: Center(
        child: Text('Calendar',
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _dark,
      body: Center(
        child: Text('Profile',
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
    );
  }
}
