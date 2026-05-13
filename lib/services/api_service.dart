import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API service for the Huni backend (PHP/MySQL on XAMPP).
class ApiService {
  static const String _baseUrl = 'http://localhost/huni_api';
  static const Duration _timeout = Duration(seconds: 8);

  // ───────────────────────────────────────────────────────────────
  // REGISTER
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String confirmPassword,
    required String email,
    required String role, // 'normal' or 'teacher'
    String firstName = '',
    String lastName = '',
    String teacherIdNumber = '',
  }) async {
    if (username.trim().isEmpty)
      return {'success': false, 'error': 'Username is required.'};
    if (password.isEmpty)
      return {'success': false, 'error': 'Password is required.'};
    if (password.length < 4)
      return {
        'success': false,
        'error': 'Password must be at least 4 characters.',
      };
    if (password != confirmPassword)
      return {'success': false, 'error': 'Passwords do not match.'};
    if (email.trim().isEmpty)
      return {'success': false, 'error': 'Email is required.'};
    if (!_looksLikeEmail(email.trim()))
      return {'success': false, 'error': 'Please enter a valid email address.'};
    if (role != 'normal' && role != 'teacher')
      return {'success': false, 'error': 'Invalid role.'};
    if (role == 'teacher' && teacherIdNumber.trim().isEmpty)
      return {'success': false, 'error': 'Teacher ID is required.'};
    if (firstName.trim().isEmpty)
      return {'success': false, 'error': 'First name is required.'};
    if (lastName.trim().isEmpty)
      return {'success': false, 'error': 'Last name is required.'};

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/register.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'username': username.trim(),
              'password': password,
              'confirm_password': confirmPassword,
              'email': email.trim(),
              'role': role,
              'first_name': firstName.trim(),
              'last_name': lastName.trim(),
              'teacher_id_number': teacherIdNumber.trim(),
            },
          )
          .timeout(_timeout);

      if (res.statusCode != 200)
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      final body = _safeDecode(res.body);
      return body ??
          {
            'success': false,
            'error': 'Invalid server response. Check the API URL.',
          };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot reach server. Check API URL and Apache status.',
      };
    }
  }

  // ───────────────────────────────────────────────────────────────
  // LOGIN
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    if (username.trim().isEmpty)
      return {'success': false, 'error': 'Username is required.'};
    if (password.isEmpty)
      return {'success': false, 'error': 'Password is required.'};

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/login.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': username.trim(), 'password': password},
          )
          .timeout(_timeout);

      if (res.statusCode != 200)
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      final body = _safeDecode(res.body);
      return body ??
          {
            'success': false,
            'error': 'Invalid server response. Check the API URL.',
          };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot reach server. Check API URL and Apache status.',
      };
    }
  }

  // ───────────────────────────────────────────────────────────────
  // CREATE STUDENT (teacher only)
  static Future<Map<String, dynamic>> createStudent({
    required int teacherUserId,
    required String username,
    required String password,
    int? classId,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final usernameRe = RegExp(r'^[A-Za-z0-9._]{5,30}$');
    if (!usernameRe.hasMatch(username.trim()))
      return {
        'success': false,
        'error': 'Username must be 5–30 chars, only letters, numbers, . and _',
      };

    final passRe = RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    if (!passRe.hasMatch(password))
      return {
        'success': false,
        'error':
            'Password must be ≥8 chars, include uppercase, number, special char',
      };

    if (email.trim().isEmpty)
      return {'success': false, 'error': 'Email is required.'};
    if (!_looksLikeEmail(email.trim()))
      return {'success': false, 'error': 'Please enter a valid email address.'};

    if (firstName.trim().isEmpty || lastName.trim().isEmpty)
      return {'success': false, 'error': 'First and last name are required.'};

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/create_student.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'teacher_user_id': '$teacherUserId',
              'username': username.trim(),
              'password': password,
              'first_name': firstName.trim(),
              'last_name': lastName.trim(),
              'email': email.trim(),
              if (classId != null) 'class_id': '$classId',
            },
          )
          .timeout(_timeout);

      if (res.statusCode != 200)
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      final body = _safeDecode(res.body);
      return body ??
          {
            'success': false,
            'error': 'Invalid server response. Check the API URL.',
          };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot reach server. Check API URL and Apache status.',
      };
    }
  }

  // Helpers
  static bool _looksLikeEmail(String e) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(e);
  }

  static Map<String, dynamic>? _safeDecode(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
