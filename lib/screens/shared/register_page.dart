import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import '../normal_user/home_page.dart';
import '../../constants/app_colors.dart';
import '../../services/session_storage_service.dart';

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
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _showLastNameError = false;
  bool _showFirstNameError = false;
  bool _showUsernameError = false;
  bool _showPasswordError = false;
  bool _showConfirmPasswordError = false;

  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  int _currentPage = 0;
  Timer? _timer;

  final List<String> _backgroundImages = [
    'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1470&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1744527912638-5d30b9908313?q=80&w=627&auto=format&fit=crop',
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
    _lastName.dispose();
    _firstName.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _register() async {
    setState(() {
      _showLastNameError = _lastName.text.trim().isEmpty;
      _showFirstNameError = _firstName.text.trim().isEmpty;
      _showUsernameError = _username.text.trim().isEmpty;
      _showPasswordError = _password.text.isEmpty;
      _showConfirmPasswordError =
          _confirmPassword.text.isEmpty ||
          _confirmPassword.text != _password.text;
    });

    if (_showLastNameError ||
        _showFirstNameError ||
        _showUsernameError ||
        _showPasswordError ||
        _showConfirmPasswordError) {
      if (_password.text.isNotEmpty &&
          _confirmPassword.text.isNotEmpty &&
          _confirmPassword.text != _password.text) {
        _showError('Passwords do not match.');
      } else {
        _showError('Please fill in all required fields.');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _username.text.trim();
      final taken = await SessionStorageService.isUsernameTaken(username);
      if (taken) {
        if (!mounted) return;
        setState(() {
          _showUsernameError = true;
          _isLoading = false;
        });
        _showError('Username is already taken.');
        return;
      }

      await SessionStorageService.saveRegisteredAccount(
        username: username,
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
      );
      await SessionStorageService.saveUsername(username);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primaryCyan,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool showError = false,
    String? errorText,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showError && errorText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppColors.errorRed,
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.6),
              fontFamily: 'Roboto',
            ),
            filled: true,
            fillColor: AppColors.inputBg,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showError
                  ? const BorderSide(color: AppColors.errorRed, width: 1.5)
                  : BorderSide.none,
            ),
          ),
        ),
      ],
    );
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
                  height: 220,
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
                      height: 220,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: Colors.black);
                      },
                      errorBuilder: (_, _, _) => Container(color: Colors.black),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CustomPaint(
                    painter: CurvedBottomPainter(),
                    size: const Size(double.infinity, 60),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                  Text(
                    'as Normal User',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 28),
                  _sectionLabel('Personal Information'),
                  _field(
                    controller: _lastName,
                    hint: 'Last Name',
                    showError: _showLastNameError,
                    errorText: 'Last name is required',
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _firstName,
                    hint: 'First Name',
                    showError: _showFirstNameError,
                    errorText: 'First name is required',
                  ),
                  const SizedBox(height: 28),
                  _sectionLabel('Login Information'),
                  _field(
                    controller: _username,
                    hint: 'Username',
                    showError: _showUsernameError,
                    errorText: 'Username is required or taken',
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _password,
                    hint: 'Password',
                    obscure: _obscurePassword,
                    showError: _showPasswordError,
                    errorText: 'Password is required',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _confirmPassword,
                    hint: 'Re-type Password',
                    obscure: _obscureConfirmPassword,
                    showError: _showConfirmPasswordError,
                    errorText: 'Passwords do not match',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _register(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.grey,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryCyan,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppColors.primaryCyan
                            .withValues(alpha: 0.5),
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
                  const SizedBox(height: 12),
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
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
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
