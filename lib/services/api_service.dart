import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Base URL ───────────────────────────────────────────────────────────────
  // Android emulator  → 10.0.2.2  (maps to your PC's localhost)
  // Real device (WiFi) → change to your PC's local IP, e.g. 192.168.1.10
  static const String baseUrl = "http://10.0.2.2/huni_api";
  static const _timeout = Duration(seconds: 10);

  // ── register ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
    String confirmPassword,
    String email,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/register.php"),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              "username": username,
              "password": password,
              "confirm_password": confirmPassword,
              "email": email,
            },
          )
          .timeout(_timeout);

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please check your network.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Server may be offline.',
      };
    } on FormatException {
      return {
        'success': false,
        'error': 'Unexpected server response. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred: $e',
      };
    }
  }

  // ── login ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login.php"),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              "username": username,
              "password": password,
            },
          )
          .timeout(_timeout);

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data;
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please check your network.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Connection timed out. Server may be offline.',
      };
    } on FormatException {
      return {
        'success': false,
        'error': 'Unexpected server response. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'An error occurred: $e',
      };
    }
  }
}
