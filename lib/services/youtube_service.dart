import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thin wrapper around the YouTube Data API v3 search endpoint.
///
/// ► How to get an API key:
///   1. Go to https://console.cloud.google.com/apis/credentials
///   2. Create a project → Enable "YouTube Data API v3"
///   3. Create an API Key → paste it below
class YouTubeService {
  // ── Replace this with your real YouTube Data API v3 key ──────────────────
  static const String apiKey = 'AIzaSyAfmjtC06Ih1T6_qpZ83Q-WzyuI6qYfQCg';
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the first YouTube video ID matching "[title] [artist] karaoke".
  /// Returns [null] if the key is not set, network fails, or no result found.
  static Future<String?> searchVideoId({
    required String title,
    required String artist,
  }) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/search',
        {
          'part': 'snippet',
          'q': '$title $artist karaoke',
          'type': 'video',
          'maxResults': '1',
          'key': apiKey,
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final items = body['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final id = items[0]['id'] as Map<String, dynamic>?;
          return id?['videoId'] as String?;
        }
      }
    } catch (_) {
      // Network error / timeout — fall through to return null
    }
    return null;
  }
}
