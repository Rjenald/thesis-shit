import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/pitch_server_config.dart';

/// Account result: either a signed-in user, or a reason it failed that the
/// UI can show the person.
class AuthResult {
  final bool ok;
  final String? username;
  final String? email;
  final String? firstName;
  final String? lastName;

  /// Granted by the database's users.is_admin column, never by the client.
  final bool isAdmin;

  /// Null when [ok]; otherwise a message safe to show the user.
  final String? error;

  /// True when the failure was reaching the server at all, rather than bad
  /// credentials — the UI says "can't reach the server" instead of wrongly
  /// telling someone their password is incorrect.
  final bool isNetworkError;

  const AuthResult._({
    required this.ok,
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.isAdmin = false,
    this.error,
    this.isNetworkError = false,
  });

  factory AuthResult.success(Map<String, dynamic> user) => AuthResult._(
        ok: true,
        username: user['username'] as String?,
        email: user['email'] as String?,
        firstName: user['firstName'] as String?,
        lastName: user['lastName'] as String?,
        isAdmin: user['isAdmin'] == true,
      );

  factory AuthResult.failure(String message) =>
      AuthResult._(ok: false, error: message);

  factory AuthResult.offline(String message) =>
      AuthResult._(ok: false, error: message, isNetworkError: true);
}

/// Accounts live in the huni_db MySQL database, reached through the backend
/// API — never by connecting to MySQL from the app, which would mean
/// shipping database credentials inside the APK.
///
/// This replaces the previous device-local account list. That version let
/// anyone register on a phone and sign in regardless of what the database
/// contained, while the accounts actually in huni_db could not sign in at
/// all, and it kept passwords in plain text. The database is now the only
/// source of truth and passwords are bcrypt-hashed server-side.
class AuthService {
  AuthService._();

  static const _timeout = Duration(seconds: 10);

  /// The auth API's base URL, derived from the same host as the pitch
  /// server so there's one address to change when the network does.
  static String get _base =>
      'http://${PitchServerConfig.serverIp}:${AuthConfig.port}';

  /// Set [requireAdmin] for the admin screen: the server then rejects an
  /// otherwise-valid account that lacks admin rights, so the decision is
  /// made by the database rather than trusted from the app.
  static Future<AuthResult> login({
    required String username,
    required String password,
    bool requireAdmin = false,
  }) =>
      _post('/auth/login', {
        'username': username,
        'password': password,
        'requireAdmin': requireAdmin,
      });

  static Future<AuthResult> register({
    required String username,
    required String password,
    required String email,
    String? firstName,
    String? lastName,
  }) =>
      _post('/auth/register', {
        'username': username,
        'password': password,
        'email': email,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      });

  /// Whether the API — and the database behind it — can be reached.
  static Future<bool> isReachable() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/auth/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_base$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      final decoded = res.body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && decoded['ok'] == true) {
        return AuthResult.success(decoded['user'] as Map<String, dynamic>);
      }

      final detail = decoded['detail'];
      final message = detail is String
          ? detail
          : 'Something went wrong (${res.statusCode}).';

      // 503 means the API is up but MySQL isn't — a server problem, not a
      // wrong password, so it's reported as such.
      return res.statusCode == 503
          ? AuthResult.offline(message)
          : AuthResult.failure(message);
    } on SocketException {
      return AuthResult.offline(
          'Cannot reach the Huni server at ${PitchServerConfig.serverIp}. '
          'Check it is running and that you are on the same network.');
    } on HttpException {
      return AuthResult.offline('Lost connection to the Huni server.');
    } catch (e) {
      debugPrint('Auth request failed: $e');
      return AuthResult.offline(
          'Could not reach the Huni server. Check your connection.');
    }
  }
}

class AuthConfig {
  /// The auth API's port. Separate from the pitch server's 8000 because
  /// auth_api.py runs as its own process; override without a rebuild via
  /// --dart-define=AUTH_PORT=...
  static const int port =
      int.fromEnvironment('AUTH_PORT', defaultValue: 8001);
}
