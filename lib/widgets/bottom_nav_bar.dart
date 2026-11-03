import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/normal_user/home_page.dart';
import '../screens/normal_user/library_page.dart';
import '../screens/normal_user/record_selection_page.dart';
import '../screens/normal_user/education_mode_page.dart';

/// The four-tab bar along the bottom of the main screens.
///
/// It owns its own navigation. It used to also take a required `onTap`
/// callback, which it never called — every screen passed a handler that
/// duplicated this routing and then never ran, and two screens passed an
/// empty closure. Removing the parameter is the only way to make the two
/// agree: a bar that both navigates and reports the tap would navigate
/// twice.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
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
    // Each tab takes a quarter of the bar rather than its natural width,
    // so the row can never total more than the screen however wide the
    // labels get. spaceAround only distributes what is left over; it
    // cannot shrink children that already do not fit.
    return [
      Expanded(child: _buildNavItem(Icons.home, 'Home', 0, context)),
      Expanded(child: _buildNavItem(Icons.library_music, 'Library', 1, context)),
      Expanded(
          child: _buildNavItem(Icons.add_circle_outline, 'Record', 2, context)),
      Expanded(child: _buildNavItem(Icons.school, 'Training', 3, context)),
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
      // Behind the label, not just under it: with only the Column's own
      // width the tap target was as narrow as the word, so "Home" was
      // noticeably harder to hit than "Training".
      behavior: HitTestBehavior.opaque,
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
            maxLines: 1,
            textAlign: TextAlign.center,
            // The four labels are sized by their text, so at a larger
            // system font they stopped fitting across the bar and the
            // last one was clipped. Ellipsised rather than wrapped: a
            // second line would push the bar taller on every screen.
            overflow: TextOverflow.ellipsis,
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
