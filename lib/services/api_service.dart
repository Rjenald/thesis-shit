import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.43.246/huni_api';
  static const Duration _timeout = Duration(seconds: 8);

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String confirmPassword,
    required String email,
    required String role,
    String firstName = '',
    String lastName = '',
    String teacherIdNumber = '',
  }) async {
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

      debugPrint('=== REGISTER RAW RESPONSE ===');
      debugPrint('Status: ${res.statusCode}');
      debugPrint('Body: ${res.body}');
      debugPrint('=============================');

      if (res.statusCode != 200)
        return {'success': false, 'error': 'Server error (${res.statusCode})'};
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
      debugPrint('=== REGISTER EXCEPTION: $e ===');
      return {'success': false, 'error': 'Cannot reach server: $e'};
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/login.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': username.trim(), 'password': password},
          )
          .timeout(_timeout);

      debugPrint('=== LOGIN RAW RESPONSE ===');
      debugPrint('Status: ${res.statusCode}');
      debugPrint('Body: ${res.body}');
      debugPrint('==========================');

      if (res.statusCode != 200)
        return {'success': false, 'error': 'Server error (${res.statusCode})'};
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
      debugPrint('=== LOGIN EXCEPTION: $e ===');
      return {'success': false, 'error': 'Cannot reach server: $e'};
    }
  }

  static Future<Map<String, dynamic>> createStudent({
    required int teacherUserId,
    required String username,
    required String password,
    int? classId,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
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

      debugPrint('=== CREATE STUDENT RAW RESPONSE ===');
      debugPrint('Status: ${res.statusCode}');
      debugPrint('Body: ${res.body}');
      debugPrint('====================================');

      if (res.statusCode != 200)
        return {'success': false, 'error': 'Server error (${res.statusCode})'};
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
      debugPrint('=== CREATE STUDENT EXCEPTION: $e ===');
      return {'success': false, 'error': 'Cannot reach server: $e'};
    }
  }

  static bool _looksLikeEmail(String e) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(e);
  }

  static Map<String, dynamic>? _safeDecode(String body) {
    debugPrint('=== _safeDecode INPUT ===');
    debugPrint(body);
    debugPrint('========================');
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      debugPrint('=== JSON DECODE ERROR: $e ===');
      return null;
    }
  }
}
