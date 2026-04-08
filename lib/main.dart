import 'package:flutter/material.dart';
import 'screens/splash_screen.dart'; // or start_page.dart

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Roboto',
      ),
      home:
          const SplashScreen(), // or const StartPage() if you fixed the constructor
    );
  }
}
