import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'teacher_account_page.dart';
import '../constants/app_colors.dart';
import '../widgets/curve_painter.dart';
import '../services/api_service.dart';
import '../services/session_storage_service.dart';

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
  bool _isTeacher = false;
  bool _wrongCode = false;

  // Teacher access code — change this to your chosen code
  static const _teacherCode = 'MAPEH2024';

  final TextEditingController username = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();
  final TextEditingController teacherCodeCtrl = TextEditingController();

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://images.unsplash.com/photo-1744527912638-5d30b9908313?q=80&w=627&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1470&auto=format&fit=crop',
  ];

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
    username.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    teacherCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      showUsernameError = false;
      showPasswordError = false;
      _wrongCode = false;
    });

    if (_isTeacher &&
        teacherCodeCtrl.text.trim().toUpperCase() != _teacherCode) {
      setState(() => _wrongCode = true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final registerData = await ApiService.register(
        username.text.trim(),
        password.text,
        confirmPassword.text,
        email.text.trim(),
      );

      if (!mounted) return;

      if (registerData['success'] == true) {
        final name =
            username.text.trim().isEmpty ? 'User' : username.text.trim();
        await SessionStorageService.saveUsername(name);
        await SessionStorageService.saveRole(
            _isTeacher ? 'teacher' : 'student');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _isTeacher ? const TeacherAccountPage() : const HomePage(),
          ),
          (route) => false,
        );
      } else {
        final error = registerData['error'] ?? 'Registration failed.';
        if (error.toLowerCase().contains('username')) {
          setState(() => showUsernameError = true);
        } else if (error.toLowerCase().contains('password')) {
          setState(() => showPasswordError = true);
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background carousel
          PageView.builder(
            controller: _pageController,
            itemCount: _backgroundImages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                _backgroundImages[index],
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
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

          // Page indicator dots
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: Row(
              children: List.generate(
                _backgroundImages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primaryCyan
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom form sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 650),
              painter: CurvePainter(),
              child: Container(
                height: 650,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      const Center(
                        child: Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryCyan,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          'Singing brings joy to the heart',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.white.withValues(alpha: 0.7),
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Username field
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
                          hintText: 'Create Username',
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

                      // Email field
                      TextField(
                        controller: email,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
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

                      // Password field
                      if (showPasswordError)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            'Invalid password format',
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
                              setState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Confirm password field
                      TextField(
                        controller: confirmPassword,
                        obscureText: obscureRePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Re-password',
                          hintStyle: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.6),
                            fontFamily: 'Roboto',
                          ),
                          filled: true,
                          fillColor: AppColors.inputBg,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureRePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.grey,
                            ),
                            onPressed: () {
                              setState(
                                () => obscureRePassword = !obscureRePassword,
                              );
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Teacher Account toggle
                      GestureDetector(
                        onTap: () => setState(() {
                          _isTeacher = !_isTeacher;
                          _wrongCode = false;
                          teacherCodeCtrl.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isTeacher
                                ? AppColors.primaryCyan.withValues(alpha: 0.12)
                                : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _isTeacher
                                  ? AppColors.primaryCyan.withValues(alpha: 0.5)
                                  : AppColors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 16,
                                color: _isTeacher
                                    ? AppColors.primaryCyan
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Register as Teacher',
                                style: TextStyle(
                                  color: _isTeacher
                                      ? AppColors.primaryCyan
                                      : AppColors.grey,
                                  fontSize: 13,
                                  fontFamily: 'Roboto',
                                  fontWeight: _isTeacher
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isTeacher
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: _isTeacher
                                    ? AppColors.primaryCyan
                                    : AppColors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Teacher code field (shown only when teacher is selected)
                      if (_isTeacher) ...[
                        const SizedBox(height: 12),
                        if (_wrongCode)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Incorrect teacher access code',
                              style: TextStyle(
                                color: AppColors.errorRed,
                                fontSize: 12,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                        TextField(
                          controller: teacherCodeCtrl,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) {
                            if (_wrongCode) setState(() => _wrongCode = false);
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. MAPEH2024',
                            hintStyle: TextStyle(
                              color: AppColors.grey.withValues(alpha: 0.6),
                              fontFamily: 'Roboto',
                            ),
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.primaryCyan, size: 18),
                            filled: true,
                            fillColor: AppColors.inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _wrongCode
                                    ? AppColors.errorRed
                                    : Colors.transparent,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _wrongCode
                                    ? AppColors.errorRed
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Register button
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
                            elevation: 0,
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
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: 'Have an account? ',
                              style: TextStyle(
                                color: AppColors.grey.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontFamily: 'Roboto',
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
