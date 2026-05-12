import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
 
/// API service for the Huni backend (PHP/MySQL on XAMPP).
///
/// IMPORTANT — base URL:
///   • Android emulator → http://10.0.2.2/huni_api
///   • iOS simulator   → http://localhost/huni_api
///   • Physical device → http://<your-pc-LAN-ip>/huni_api
class ApiService {
  static const String _baseUrl = 'http://localhost/huni_api';
  static const Duration _timeout = Duration(seconds: 8);
 
  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────────────────────────────────
  /// Registers a NORMAL user or a TEACHER.
  /// Students are NOT created here — teachers create them via [createStudent].
  ///
  /// Returns:
  ///   { success: true,  id: <int>, role: <string> }
  /// or
  ///   { success: false, error: <string> }
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
    // ── Client-side validation — never hit the server on bad input ─────────
    if (username.trim().isEmpty) {
      return {'success': false, 'error': 'Username is required.'};
    }
    if (password.isEmpty) {
      return {'success': false, 'error': 'Password is required.'};
    }
    if (password.length < 4) {
      return {'success': false, 'error': 'Password must be at least 4 characters.'};
    }
    if (password != confirmPassword) {
      return {'success': false, 'error': 'Passwords do not match.'};
    }
    if (email.trim().isEmpty) {
      return {'success': false, 'error': 'Email is required.'};
    }
    if (!_looksLikeEmail(email.trim())) {
      return {'success': false, 'error': 'Please enter a valid email address.'};
    }
    if (role != 'normal' && role != 'teacher') {
      return {'success': false, 'error': 'Invalid role.'};
    }
    if (role == 'teacher' && teacherIdNumber.trim().isEmpty) {
      return {'success': false, 'error': 'Teacher ID is required.'};
    }
    if (firstName.trim().isEmpty) {
      return {'success': false, 'error': 'First name is required.'};
    }
    if (lastName.trim().isEmpty) {
      return {'success': false, 'error': 'Last name is required.'};
    }
 
    // ── Network call ───────────────────────────────────────────────────────
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
 
      if (res.statusCode != 200) {
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      }
 
      final body = _safeDecode(res.body);
      if (body == null) {
        return {
          'success': false,
          'error': 'Invalid server response. Check the API URL.',
        };
      }
      return body;
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error':
            'Cannot reach server. Make sure XAMPP/Apache is running and the API URL is correct.',
      };
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────────────────
  /// Returns the user profile + role for routing.
  ///
  /// Returns:
  ///   { success: true, id, username, role, first_name, last_name,
  ///     email, teacher_id_number, created_by, class_id }
  /// or
  ///   { success: false, error: <string> }
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    // ── Client-side validation ─────────────────────────────────────────────
    if (username.trim().isEmpty) {
      return {'success': false, 'error': 'Username is required.'};
    }
    if (password.isEmpty) {
      return {'success': false, 'error': 'Password is required.'};
    }
 
    // ── Network call ───────────────────────────────────────────────────────
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/login.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'username': username.trim(),
              'password': password,
            },
          )
          .timeout(_timeout);
 
      if (res.statusCode != 200) {
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      }
 
      final body = _safeDecode(res.body);
      if (body == null) {
        return {
          'success': false,
          'error': 'Invalid server response. Check the API URL.',
        };
      }
      return body;
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error':
            'Cannot reach server. Make sure XAMPP/Apache is running and the API URL is correct.',
      };
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // CREATE STUDENT (teacher only)
  // ─────────────────────────────────────────────────────────────────────────
  /// Creates a student account on behalf of the calling teacher.
  /// The server verifies that [teacherUserId] is in fact a teacher.
  ///
  /// Returns:
  ///   { success: true, id: <int> }
  /// or
  ///   { success: false, error: <string> }
  static Future<Map<String, dynamic>> createStudent({
    required int teacherUserId,
    required String username,
    required String password,
    int? classId,
    String firstName = '',
    String lastName = '',
    String email = '',
  }) async {
    // ── Client-side validation ─────────────────────────────────────────────
    if (username.trim().isEmpty) {
      return {'success': false, 'error': 'Student username is required.'};
    }
    if (password.isEmpty) {
      return {'success': false, 'error': 'A temporary password is required.'};
    }
    if (password.length < 4) {
      return {'success': false, 'error': 'Password must be at least 4 characters.'};
    }
    if (email.trim().isNotEmpty && !_looksLikeEmail(email.trim())) {
      return {'success': false, 'error': 'Please enter a valid email address.'};
    }
 
    // ── Network call ───────────────────────────────────────────────────────
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/create_student.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'teacher_user_id': '$teacherUserId',
              'username': username.trim(),
              'password': password,
              if (classId != null) 'class_id': '$classId',
              'first_name': firstName.trim(),
              'last_name': lastName.trim(),
              'email': email.trim(),
            },
          )
          .timeout(_timeout);
 
      if (res.statusCode != 200) {
        return {
          'success': false,
          'error': 'Server error (${res.statusCode}). Please try again.',
        };
      }
 
      final body = _safeDecode(res.body);
      if (body == null) {
        return {
          'success': false,
          'error': 'Invalid server response. Check the API URL.',
        };
      }
      return body;
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Server timed out. Check your XAMPP/Apache is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error':
            'Cannot reach server. Make sure XAMPP/Apache is running and the API URL is correct.',
      };
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
 
  /// Lightweight email format check. The PHP server still does the MX-record
  /// check via checkdnsrr, so this is just a quick UX filter.
  static bool _looksLikeEmail(String e) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(e);
  }
 
  /// Decode JSON safely. Returns null if the body isn't a JSON object.
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
 