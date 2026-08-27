import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/normal_user/home_page.dart';
import '../screens/normal_user/library_page.dart';
import '../screens/normal_user/record_selection_page.dart';
import '../screens/normal_user/education_mode_page.dart';

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
    return [
      _buildNavItem(Icons.home, 'Home', 0, context),
      _buildNavItem(Icons.library_music, 'Library', 1, context),
      _buildNavItem(Icons.add_circle_outline, 'Record', 2, context),
      _buildNavItem(Icons.school, 'Training', 3, context),
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
        if (index == 0) {
          destination = const HomePage();
        } else if (index == 1) {
          destination = const LibraryPage();
        } else if (index == 2) {
          destination = const RecordSelectionPage();
        } else {
          destination = const EducationModePage();
        }

        // Slide left/right based on tab direction (higher index → from right)
        final slideFromRight = index > currentIndex;
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (ctx, anim, sec) => destination,
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (ctx, animation, sec, child) {
              final tween = Tween<Offset>(
                begin: Offset(slideFromRight ? 1.0 : -1.0, 0.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeInOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
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
