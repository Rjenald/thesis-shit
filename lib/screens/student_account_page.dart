import 'package:flutter/material.dart';
import '../data/tagalog_bisaya_songs.dart';
import 'karaoke_recording_page.dart';
import 'practice_solfege_page.dart';
import 'karaoke_practice_mode_page.dart';
import 'login_page.dart';

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
        page = StudentSolfegeActivityPage(
          className: className,
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
      bottomNavigationBar: _buildStudentNav(context),
    );
  }

  Widget _buildStudentNav(BuildContext context) {
    return Container(
      color: _navBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.notifications_outlined, 'Notification'),
              _navItem(Icons.mic_none, 'Karaoke Mode'),
              _navItem(Icons.home_outlined, 'Home',
                  onTap: () => Navigator.pop(context)),
              _navItem(Icons.calendar_today_outlined, 'Calendar'),
              _navItem(Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ==================== STUDENT SOLFEGE ACTIVITY PAGE ====================

class StudentSolfegeActivityPage extends StatefulWidget {
  final String className;
  final String lessonTitle;

  const StudentSolfegeActivityPage({
    super.key,
    required this.className,
    required this.lessonTitle,
  });

  @override
  State<StudentSolfegeActivityPage> createState() =>
      _StudentSolfegeActivityPageState();
}

class _StudentSolfegeActivityPageState
    extends State<StudentSolfegeActivityPage> {
  // Note grid — two columns, 5 rows (matches Figma)
  static const _noteRows = [
    ['Do', 'Mi'],
    ['Mi', 'Mi'],
    ['Fa', 'Mi'],
    ['So', 'La'],
    ['La', 'Mi'],
  ];

  bool _isRecording = false;
  final String _hitNote = 'Do';
  final double _pitchOffset = 0.0; // -1 = too high, 0 = center, 1 = too low
  final double _score = 90.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Cyan header ──────────────────────────────────────────────
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
                    Text(
                      widget.className.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    '${widget.lessonTitle}  /  Solfege Activity',
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable body ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instruction box
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5A5A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Instruction:',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note grid (2 columns × 5 rows)
                  ..._noteRows.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: _noteCell(row[0])),
                          const SizedBox(width: 8),
                          Expanded(child: _noteCell(row[1])),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Hit Note + NO badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Hit Note: ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Text(_hitNote,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('NO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pitch indicator
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      final thumbX =
                          (w * (0.5 + _pitchOffset * 0.35)).clamp(1.0, w - 3);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.white12, width: 0.5),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 21,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                      height: 1, color: Colors.white24),
                                ),
                                Positioned(
                                  top: 10,
                                  left: thumbX,
                                  child: Container(
                                      width: 2,
                                      height: 24,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOO HIGH',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 8)),
                              Text('TOO LOW',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 8)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Score
                  Container(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Score  ',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          Text('${_score.round()}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Record button
                  Center(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _isRecording = !_isRecording),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color:
                              _isRecording ? Colors.red.shade700 : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Submit',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStudentNav(context),
    );
  }

  Widget _noteCell(String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      alignment: Alignment.center,
      child: Text(note,
          style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStudentNav(BuildContext context) {
    return Container(
      color: _navBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.notifications_outlined, 'Notification'),
              _navItem(Icons.mic_none, 'Karaoke Mode'),
              _navItem(Icons.home_outlined, 'Home',
                  onTap: () => Navigator.pop(context)),
              _navItem(Icons.calendar_today_outlined, 'Calendar'),
              _navItem(Icons.person_outline, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

// ==================== CALENDAR SCREEN ====================

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _today;
  late DateTime _focusedMonth;
  bool _calendarHidden = false;

  // Demo due-date events (relative to today so they always show in the week view)
  late final List<Map<String, dynamic>> _events;
  final List<String> _todos = ['comscii!!!!!!!!!'];
  static const int _assignmentsDue = 13;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _focusedMonth = DateTime(_today.year, _today.month, 1);

    // Put events on the Tuesday & Wednesday of the current week
    final sundayOfWeek =
        _today.subtract(Duration(days: _today.weekday % 7));
    final tue = sundayOfWeek.add(const Duration(days: 2));
    final wed = sundayOfWeek.add(const Duration(days: 3));
    _events = [
      {'date': tue, 'title': 'Due: 05 Activity 1'},
      {'date': tue, 'title': 'Due: 05 Practice Exercise 1'},
      {'date': tue, 'title': 'Due: 05 Task Performance 1 – ARG'},
      {'date': wed, 'title': 'Due: 06 Task Performance 1 – ARG'},
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasEvent(DateTime d) =>
      _events.any((e) => _isSameDay(e['date'] as DateTime, d));

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ─────────────────────────────────────────────────
              const Row(
                children: [
                  Icon(Icons.calendar_today, color: _cyan, size: 18),
                  SizedBox(width: 8),
                  Text('Calendar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Mini month calendar ────────────────────────────────────
              if (!_calendarHidden) ...[
                // Month navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _focusedMonth =
                          DateTime(_focusedMonth.year,
                              _focusedMonth.month - 1)),
                      child: const Icon(Icons.chevron_left,
                          color: Colors.white70, size: 22),
                    ),
                    Text(
                      '${_monthNames[_focusedMonth.month]} ${_focusedMonth.year}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _focusedMonth =
                          DateTime(_focusedMonth.year,
                              _focusedMonth.month + 1)),
                      child: const Icon(Icons.chevron_right,
                          color: Colors.white70, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Day-of-week header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((h) => SizedBox(
                            width: 32,
                            child: Center(
                              child: Text(h,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 6),

                // Date grid
                _buildMonthGrid(),
                const SizedBox(height: 12),
              ],

              // ── full calendar | hide ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FullCalendarPage(events: _events)),
                    ),
                    child: const Text('full calendar',
                        style: TextStyle(
                            color: _cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _calendarHidden = !_calendarHidden),
                    child: Text(
                      _calendarHidden ? 'show' : 'hide',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),

              // ── To-do section ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: _cyan, size: 18),
                      SizedBox(width: 6),
                      Text('To-do',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.add,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Assignments due
              _todoRow(
                icon: Icons.description_outlined,
                text: '$_assignmentsDue assignments due',
                color: _cyan,
              ),
              const SizedBox(height: 6),

              // Todo items
              ..._todos.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _todoRow(
                    icon: Icons.push_pin_outlined,
                    text: t,
                    color: Colors.white70,
                    trailing: GestureDetector(
                      onTap: () => setState(() => _todos.remove(t)),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white38, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Month grid ──────────────────────────────────────────────────────────────
  Widget _buildMonthGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final firstDow = firstDay.weekday % 7; // 0 = Sun
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;

    final cells = <Widget>[
      ...List.generate(firstDow, (_) => const SizedBox(width: 32, height: 32)),
      ...List.generate(daysInMonth, (i) {
        final day = i + 1;
        final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
        final isToday = _isSameDay(date, _today);
        final bold = _hasEvent(date);
        return SizedBox(
          width: 32,
          height: 32,
          child: Container(
            decoration: isToday
                ? const BoxDecoration(color: _cyan, shape: BoxShape.circle)
                : null,
            alignment: Alignment.center,
            child: Text('$day',
                style: TextStyle(
                    color: isToday ? Colors.black : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final slice = cells.sublist(i, (i + 7).clamp(0, cells.length));
      while (slice.length < 7) {
        slice.add(const SizedBox(width: 32, height: 32));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: slice),
      ));
    }
    return Column(children: rows);
  }

  Widget _todoRow({
    required IconData icon,
    required String text,
    required Color color,
    Widget? trailing,
  }) =>
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500))),
        ?trailing,
      ]);
}

// ==================== FULL CALENDAR PAGE (week view) ====================

class FullCalendarPage extends StatefulWidget {
  final List<Map<String, dynamic>> events;
  const FullCalendarPage({super.key, required this.events});

  @override
  State<FullCalendarPage> createState() => _FullCalendarPageState();
}

class _FullCalendarPageState extends State<FullCalendarPage> {
  late DateTime _today;
  late DateTime _weekStart;
  String _view = 'Week';

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _hours = [
    '12pm', '1pm', '2pm', '3pm', '4pm', '5pm',
    '6pm', '7pm', '8pm', '9pm', '10pm', '11pm',
  ];

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    final dow = _today.weekday % 7;
    _weekStart = _today.subtract(Duration(days: dow));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> _eventsFor(DateTime d) =>
      widget.events.where((e) => _isSameDay(e['date'] as DateTime, d)).toList();

  @override
  Widget build(BuildContext context) {
    final weekDays =
        List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: const Color(0xFF12122A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Container(
              color: const Color(0xFF1A1A2E),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  // Back arrow
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 6),
                  // Today
                  _topBtn('Today', onTap: () {
                    setState(() {
                      _today = DateTime.now();
                      final dow = _today.weekday % 7;
                      _weekStart = _today.subtract(Duration(days: dow));
                    });
                  }),
                  const SizedBox(width: 6),
                  // Prev / Next
                  _arrowBtn(Icons.chevron_left,
                      () => setState(() => _weekStart =
                          _weekStart.subtract(const Duration(days: 7)))),
                  const SizedBox(width: 4),
                  _arrowBtn(Icons.chevron_right,
                      () => setState(() => _weekStart =
                          _weekStart.add(const Duration(days: 7)))),
                  const Spacer(),
                  // View tabs
                  _viewTab('Week'),
                  const SizedBox(width: 4),
                  _viewTab('Month'),
                  const SizedBox(width: 4),
                  _viewTab('Agenda'),
                ],
              ),
            ),

            // ── Day headers ───────────────────────────────────────────
            Container(
              color: const Color(0xFF1A1A2E),
              padding:
                  const EdgeInsets.only(bottom: 10, left: 52, right: 4),
              child: Row(
                children: List.generate(7, (i) {
                  final day = weekDays[i];
                  final isToday = _isSameDay(day, _today);
                  return Expanded(
                    child: Column(
                      children: [
                        Text(_dayNames[i],
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: isToday
                              ? const BoxDecoration(
                                  color: _cyan, shape: BoxShape.circle)
                              : null,
                          alignment: Alignment.center,
                          child: Text('${day.day}',
                              style: TextStyle(
                                  color: isToday
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // ── All-day events ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white12),
                  bottom: BorderSide(color: Colors.white12),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 52,
                    child: Center(
                      child: Text('All day',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    ),
                  ),
                  ...List.generate(7, (i) {
                    final evts = _eventsFor(weekDays[i]);
                    return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: evts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final e = entry.value;
                          // alternate border colours like the screenshot
                          final borderColor =
                              idx < 3 ? _cyan : Colors.deepPurple;
                          return Container(
                            margin: const EdgeInsets.only(
                                bottom: 3, right: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E3A),
                              borderRadius: BorderRadius.circular(3),
                              border: Border(
                                left: BorderSide(
                                    color: borderColor, width: 2),
                              ),
                            ),
                            child: Text(e['title'] as String,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Hourly time slots ─────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _hours.map((label) {
                    return SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(label,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10)),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.white12, width: 0.5),
                                  left: BorderSide(
                                      color: Colors.white12, width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      // Keep the student bottom nav in the full calendar too
      bottomNavigationBar: Container(
        color: _navBg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _fcNavItem(context, Icons.notifications_outlined, 'Notification'),
                _fcNavItem(context, Icons.mic_none, 'Karaoke Mode'),
                _fcNavItem(context, Icons.home_outlined, 'Home',
                    onTap: () => Navigator.pop(context)),
                _fcNavItem(context, Icons.calendar_today_outlined, 'Calendar',
                    active: true),
                _fcNavItem(context, Icons.person_outline, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBtn(String label, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      );

  Widget _arrowBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );

  Widget _viewTab(String label) {
    final active = _view == label;
    return GestureDetector(
      onTap: () => setState(() => _view = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? _cyan : Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == 'Week'
                  ? Icons.calendar_view_week
                  : label == 'Month'
                      ? Icons.calendar_month
                      : Icons.format_list_bulleted,
              color: active ? _cyan : Colors.white38,
              size: 10,
            ),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: active ? _cyan : Colors.white54,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _fcNavItem(BuildContext context, IconData icon, String label,
      {VoidCallback? onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? _cyan : Colors.white70, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: active ? _cyan : Colors.white70,
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ==================== PROFILE SCREEN ====================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),

            // ── Avatar ────────────────────────────────────────────────
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                border: Border.all(color: _cyan, width: 2),
              ),
              child: const Icon(Icons.person,
                  color: Colors.white70, size: 52),
            ),

            const SizedBox(height: 14),

            // ── Name + class ──────────────────────────────────────────
            const Text('Student',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _cyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Grade 11 – Sampaguita',
                  style: TextStyle(
                      color: _cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),

            const SizedBox(height: 32),

            // ── Info cards ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _infoRow(Icons.school_outlined, 'Section',
                      'Grade 11 – Sampaguita'),
                  const SizedBox(height: 10),
                  _infoRow(Icons.person_outline, 'Role', 'Student'),
                  const SizedBox(height: 10),
                  _infoRow(Icons.assignment_outlined, 'Assignments Due', '13'),
                ],
              ),
            ),

            const Spacer(),

            // ── Log out button ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: _cyan, size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
