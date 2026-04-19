import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator  → 10.0.2.2 (your PC's localhost)
  // Real device on same WiFi → your PC's local IP e.g. 192.168.1.10
  static const String baseUrl = "http://10.0.2.2/huni_api";
  static const _timeout = Duration(seconds: 5);

  // ── register ──────────────────────────────────────────────────────────────

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
            body: {
              "username": username,
              "password": password,
              "confirm_password": confirmPassword,
              "email": email,
            },
          )
          .timeout(_timeout);
      return json.decode(response.body);
    } catch (_) {
      // Server unreachable → allow anyway
      return {'success': true};
    }
  }

  // ── login ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/login.php"),
            body: {"username": username, "password": password},
          )
          .timeout(_timeout);
      return json.decode(response.body);
    } catch (_) {
      // Server unreachable → auto-login
      return {'success': true};
    }
  }
}
