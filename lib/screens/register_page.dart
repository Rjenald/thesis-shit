import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'teacher_account_page.dart';
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

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool obscurePassword = true;
  bool obscureRePassword = true;
  bool showUsernameError = false;
  bool showPasswordError = false;
  bool _isLoading = false;
  String _selectedRole = '';

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1744527912638-5d30b9908313?q=80&w=627&auto=format&fit=crop',
  ];

  final TextEditingController lastName = TextEditingController();
  final TextEditingController firstName = TextEditingController();
  final TextEditingController studentId = TextEditingController();
  final TextEditingController teacherId = TextEditingController();
  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < _backgroundImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    lastName.dispose();
    firstName.dispose();
    studentId.dispose();
    teacherId.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      showUsernameError = false;
      showPasswordError = false;
    });

    setState(() => _isLoading = true);

    try {
      // STEP 1: Register
      final registerData = await ApiService.register(
        username.text.trim(),
        password.text,
        confirmPassword.text,
        email.text.trim(),
      );

      if (registerData['success'] != true) {
        if (!mounted) return;

        final error = registerData['error'] ?? 'Registration failed.';

        if (error.toLowerCase().contains('username')) {
          setState(() => showUsernameError = true);
        } else if (error.toLowerCase().contains('password')) {
          setState(() => showPasswordError = true);
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        setState(() => _isLoading = false);
        return;
      }

      // STEP 2: Auto-login
      final loginData = await ApiService.login(
        username.text.trim(),
        password.text,
      );

      if (!mounted) return;

      if (loginData['success'] == true) {
        await SessionStorageService.saveUsername(username.text.trim());
        await SessionStorageService.saveRole(_selectedRole);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => _selectedRole == 'teacher'
                ? const TeacherAccountPage()
                : const HomePage(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered! Please log in.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
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
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _backgroundImages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return Image.network(
                        _backgroundImages[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primaryCyan,
                              ),
                            ),
                          );
                        },
                      );
                    },
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
                    'Register',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryCyan,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_selectedRole != '')
                    Text(
                      _selectedRole == 'student'
                          ? 'as Student'
                          : _selectedRole == 'teacher'
                              ? 'as Teacher'
                              : 'as Normal User',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                      ),
                    )
                  else ...[
                    const SizedBox(height: 4),
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
                  ],
                  const SizedBox(height: 32),
                  if (_selectedRole == '') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => setState(() {
                          _selectedRole = 'normal';
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Normal User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24, thickness: 1),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _selectedRole = 'student';
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryCyan,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'as Student',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _selectedRole = 'teacher';
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryCyan,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'as Teacher',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
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
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'Have an account? ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                color: AppColors.primaryCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastName,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Last Name',
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: firstName,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'First Name',
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
                    const SizedBox(height: 12),
                    if (_selectedRole == 'student')
                      TextField(
                        controller: studentId,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Student ID',
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
                    if (_selectedRole == 'teacher')
                      TextField(
                        controller: teacherId,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Teacher ID',
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
                    if (_selectedRole == 'student' || _selectedRole == 'teacher')
                      const SizedBox(height: 12),
                    Text(
                      'Login Information',
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showUsernameError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          'Invalid username',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
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
                        ),
                        filled: true,
                        fillColor: AppColors.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showPasswordError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          'Invalid password',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
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
                        ),
                        filled: true,
                        fillColor: AppColors.inputBg,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassword,
                      obscureText: obscureRePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Re-type Password',
                        hintStyle: TextStyle(
                          color: AppColors.grey.withValues(alpha: 0.6),
                        ),
                        filled: true,
                        fillColor: AppColors.inputBg,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureRePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.grey,
                          ),
                          onPressed: () {
                            setState(() => obscureRePassword = !obscureRePassword);
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
                        onPressed: _isLoading ? null : _register,
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
                                'Register',
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
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: 'Have an account? ',
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Login',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
