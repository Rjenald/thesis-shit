import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/home_page.dart';
import '../screens/library_page.dart';
import '../screens/record_selection_page.dart';
import '../screens/education_mode_page.dart'; // Import EducationPage

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            children: [
              _buildNavItem(Icons.home, 'Home', 0, context),
              _buildNavItem(Icons.library_music, 'Library', 1, context),
              _buildNavItem(Icons.add_circle_outline, 'Record', 2, context),
              _buildNavItem(Icons.school, 'Education', 3, context),
            ],
          ),
        ),
      ),
    );
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
        if (index == 0) {
          destination = const HomePage();
        } else if (index == 1) {
          destination = const LibraryPage();
        } else if (index == 2) {
          destination = const RecordSelectionPage();
        } else {
          destination = const EducationModePage();
        }

        Navigator.pushReplacement(
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
