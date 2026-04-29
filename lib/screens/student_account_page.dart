import 'package:flutter/material.dart';

void main() {
  runApp(const MusicApp());
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Education App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF00ACC1), // Cyan accent
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00ACC1),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const NotificationScreen(),
    const KaraokeModeScreen(),
    const HomeScreen(),
    const CalendarScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
          Icon(
            icon,
            color: isSelected ? const Color(0xFF00ACC1) : Colors.white70,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00ACC1) : Colors.white70,
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
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'name': 'Bags, Kian Francis',
      'action': 'Added Activity | Solfage',
      'deadline': '01.01.21',
      'type': 'activity',
    },
    {
      'name': 'Bags, Kian Francis',
      'action': 'Add to Grade 11 - Sampaguita',
      'type': 'enrollment',
    },
  ];

  void _confirmNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification confirmed'),
        backgroundColor: Color(0xFF00ACC1),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteNotification(int index) {
    setState(() {
      _notifications.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification deleted'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Notification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Icon(Icons.wifi, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Icon(Icons.battery_full, color: Colors.white, size: 16),
              ],
            ),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Text(
                'No new notifications',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return NotificationCard(
                  name: notif['name'],
                  action: notif['action'],
                  deadline: notif['deadline'],
                  type: notif['type'],
                  onConfirm: () => _confirmNotification(index),
                  onDelete: () => _deleteNotification(index),
                );
              },
            ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String name;
  final String action;
  final String? deadline;
  final String type;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const NotificationCard({
    super.key,
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
      color: const Color(0xFF2A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Actions
          if (type == 'activity' && deadline != null) ...[
            Text(
              'Deadline: $deadline',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ] else if (type == 'enrollment') ...[
            TextButton(
              onPressed: onConfirm,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00ACC1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== CLASSROOM SCREEN ====================

class ClassroomScreen extends StatefulWidget {
  const ClassroomScreen({super.key});

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  bool _isEnrolled = true;

  final List<Map<String, dynamic>> _lessons = [
    {'title': 'Lesson 1: Solfege Drill', 'completed': false},
    {'title': 'Lesson 2: Karaoke Practice', 'completed': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Classroom',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Icon(Icons.wifi, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Icon(Icons.battery_full, color: Colors.white, size: 16),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Class Header / Enrollment Status
          GestureDetector(
            onTap: () {
              setState(() {
                _isEnrolled = !_isEnrolled;
              });
            },
            child: Container(
              width: double.infinity,
              color: const Color(0xFF00ACC1),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _isEnrolled ? 'Grade 11 - Sampaguita' : 'Not Enrolled yet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Lessons List (only show if enrolled)
          if (_isEnrolled)
            Expanded(
              child: ListView.builder(
                itemCount: _lessons.length,
                padding: const EdgeInsets.all(0),
                itemBuilder: (context, index) {
                  final lesson = _lessons[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.black.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text(
                  'Enroll in a class to see lessons',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== PLACEHOLDER SCREENS ====================

class KaraokeModeScreen extends StatelessWidget {
  const KaraokeModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Karaoke Mode',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Home',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Calendar',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
