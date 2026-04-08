import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2/huni_api";

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    var url = Uri.parse("$baseUrl/register.php");
    var response = await http.post(
      url,
      body: {"username": username, "password": password},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    var url = Uri.parse("$baseUrl/login.php");
    var response = await http.post(
      url,
      body: {"username": username, "password": password},
    );

    return json.decode(response.body);
  }
}
