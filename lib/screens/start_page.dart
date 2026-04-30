import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'login_page.dart';
import 'register_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  int _currentPage = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://plus.unsplash.com/premium_photo-1682920140924-d8b5db318d97?q=80&w=692&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1556848798-ee649b672584?q=80&w=627&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1600119692901-94e8b7d2eacd?q=80&w=1469&auto=format&fit=crop',
    'https://images.unsplash.com/flagged/photo-1564434369363-696a2e6d96f9?q=80&w=687&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-cache all images for smooth transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final url in _backgroundImages) {
        precacheImage(NetworkImage(url), context);
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentPage = (_currentPage + 1) % _backgroundImages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 420,
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1000),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Image.network(
                      _backgroundImages[_currentPage],
                      key: ValueKey(_currentPage),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 420,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: Colors.black);
                      },
                      errorBuilder: (_, _, _) =>
                          Container(color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: _CurvedBottomPainter(),
                    size: const Size(double.infinity, 80),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'HUNI',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryCyan,
                      fontFamily: 'Roboto',
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Singing',
                          style: TextStyle(
                            color: AppColors.primaryCyan,
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        TextSpan(
                          text: ' brings joy to the heart',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryCyan,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryCyan,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A2A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                      children: [
                        const TextSpan(
                          text: 'Huni\'s',
                          style: TextStyle(color: AppColors.primaryCyan),
                        ),
                        TextSpan(
                          text: '\nTerms of Use',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: ' and ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvedBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 50);
    path.cubicTo(size.width / 4, 0, (size.width * 3) / 4, 0, size.width, 50);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedBottomPainter oldDelegate) => false;
}
