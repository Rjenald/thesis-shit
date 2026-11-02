import 'dart:async';
import 'package:flutter/material.dart';
import 'start_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Held so it can be cancelled.
  ///
  /// It used to be fired and forgotten, which left two ways to break: a
  /// timer still pending after the tree was disposed (which is what the
  /// launch smoke test was failing on), and `Navigator.pushReplacement`
  /// called with a dead `context` if this screen went away inside the
  /// three seconds — backing out of the splash, or a hot restart.
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    _advance = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StartPage()),
      );
    });
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              // Scales with the screen instead of a fixed 180px, so it
              // can't overflow on small/short devices; capped so it
              // doesn't blow up on tablets.
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.of(context).size.width * 0.45).clamp(
                  120,
                  220,
                ),
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.cyan),
          ],
        ),
      ),
    );
  }
}
