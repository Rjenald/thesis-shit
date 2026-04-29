import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/home_page.dart';
import '../screens/library_page.dart';
import '../screens/record_selection_page.dart';
import '../screens/education_mode_page.dart';
import '../screens/notifications_page.dart';
import '../screens/student_calendar_page.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isStudent;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isStudent = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildNavItems(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bottomNavBg,
        border: Border(
          top: BorderSide(color: AppColors.inputBg.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    if (isStudent) {
      // Student account navigation (matches Figma design)
      return [
        _buildNavItem(Icons.home, 'Home', 0, context),
        _buildNavItem(Icons.calendar_today, 'Calendar', 1, context),
        _buildNavItem(Icons.music_note, 'Karaoke Mode', 2, context),
        _buildNavItem(Icons.notifications, 'Notifications', 3, context),
        _buildNavItem(Icons.person, 'Profile', 4, context),
      ];
    }
    // Original user account navigation (unchanged)
    return [
      _buildNavItem(Icons.home, 'Home', 0, context),
      _buildNavItem(Icons.library_music, 'Library', 1, context),
      _buildNavItem(Icons.add_circle_outline, 'Record', 2, context),
      _buildNavItem(Icons.school, 'Education', 3, context),
    ];
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    BuildContext context,
  ) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == currentIndex) return;

        Widget destination;
        if (isStudent) {
          // Student navigation routing
          if (index == 0) {
            destination = const HomePage();
          } else if (index == 1) {
            destination = const StudentCalendarPage();
          } else if (index == 2) {
            destination = const KaraokePage();
          } else if (index == 3) {
            destination = const NotificationsPage();
          } else {
            destination = const ProfilePage();
          }
        } else {
          // User account navigation routing (original)
          if (index == 0) {
            destination = const HomePage();
          } else if (index == 1) {
            destination = const LibraryPage();
          } else if (index == 2) {
            destination = const RecordSelectionPage();
          } else {
            destination = const EducationModePage();
          }
        }

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (ctx, anim, sec) => destination,
            transitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (ctx, animation, sec, child) => FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            ),
          ),
          (route) => route.isFirst,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primaryCyan : AppColors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primaryCyan : AppColors.grey,
              fontSize: 11,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text(
          'Calendar',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Calendar feature coming soon',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
        onTap: _noop,
        isStudent: true,
      ),
    );
  }
}

class KaraokePage extends StatelessWidget {
  const KaraokePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage(showBackButton: true);
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Profile feature coming soon',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.6),
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 4,
        onTap: _noop,
        isStudent: true,
      ),
    );
  }
}

void _noop(int _) {}
