import 'dart:async';
import 'package:flutter/material.dart';
import 'start_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StartPage()),
      );
    });
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
