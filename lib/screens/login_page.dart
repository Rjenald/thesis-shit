import 'dart:async';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'register_page.dart';
import 'teacher_account_page.dart';
import 'student_account_page.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/session_storage_service.dart';

class CurvedBottomPainter extends CustomPainter {
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
  bool shouldRepaint(CurvedBottomPainter oldDelegate) => false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool obscurePassword = true;
  bool showUsernameError = false;
  bool showPasswordError = false;
  bool _isLoading = false;

  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  int _currentPage = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://images.unsplash.com/photo-1556848798-ee649b672584?q=80&w=627&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1600119692901-94e8b7d2eacd?q=80&w=1469&auto=format&fit=crop',
    'https://images.unsplash.com/flagged/photo-1564434369363-696a2e6d96f9?q=80&w=687&auto=format&fit=crop',
    'https://plus.unsplash.com/premium_photo-1682920140924-d8b5db318d97?q=80&w=692&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
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
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      showUsernameError = false;
      showPasswordError = false;
    });

    setState(() => _isLoading = true);

    try {
      final loginData = await ApiService.login(
        username.text.trim(),
        password.text,
      );

      if (!mounted) return;

      if (loginData['success'] == true) {
        await SessionStorageService.saveUsername(username.text.trim());

        // Check role from API response or default to student
        final role = loginData['role'] ?? 'student';
        await SessionStorageService.saveRole(role);
        if (!mounted) return;

        Widget destination;
        if (role == 'teacher') {
          destination = const TeacherAccountPage();
        } else if (role == 'student') {
          destination = const StudentAccountPage();
        } else {
          destination = const HomePage();
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      } else {
        final error = loginData['error'] ?? 'Login failed.';

        if (error.toLowerCase().contains('username')) {
          setState(() => showUsernameError = true);
        } else if (error.toLowerCase().contains('password')) {
          setState(() => showPasswordError = true);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  height: 350,
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
                      height: 350,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: Colors.black);
                      },
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: CurvedBottomPainter(),
                    size: const Size(double.infinity, 80),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryCyan,
                      fontFamily: 'Roboto',
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
                  if (showUsernameError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'Invalid username',
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  TextField(
                    controller: username,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontFamily: 'Roboto',
                      ),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (showPasswordError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'Invalid password',
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontSize: 12,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ),
                  TextField(
                    controller: password,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontFamily: 'Roboto',
                      ),
                      filled: true,
                      fillColor: AppColors.inputBg,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.grey,
                        ),
                        onPressed: () {
                          setState(() => obscurePassword = !obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Register',
                            style: TextStyle(
                              color: AppColors.primaryCyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to Huni\'s ',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: 'Terms of Use',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.8),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(
                          text: ' and ',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.8),
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
