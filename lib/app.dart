import 'package:flutter/material.dart';
import 'constants/app_colors.dart';
import 'screens/welcome_screen.dart';

class HuniApp extends StatelessWidget {
  const HuniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUNI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bgDark,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeTransitionBuilder(),
            TargetPlatform.iOS: _FadeTransitionBuilder(),
            TargetPlatform.windows: _FadeTransitionBuilder(),
          },
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class _FadeTransitionBuilder extends PageTransitionsBuilder {
  const _FadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}
