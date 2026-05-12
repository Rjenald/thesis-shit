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

  /// Returns the first YouTube video ID where the original artist is singing.
  ///
  /// Strategy — tries queries from most-specific to most-permissive:
  ///   1. "[title] [artist] official video"  — official MV by the same artist
  ///   2. "[title] [artist] official"        — any official upload by the artist
  ///   3. "[title] [artist]"                 — broadest fallback
  ///
  /// Returns [null] if the key is not set, network fails, or no result found.
  static Future<String?> searchVideoId({
    required String title,
    required String artist,
  }) async {
    final queries = [
      '$title $artist official video',
      '$title $artist official',
      '$title $artist',
    ];

    for (final q in queries) {
      final id = await _fetchFirstVideoId(q);
      if (id != null) return id;
    }
    return null;
  }

  /// Searches YouTube for karaoke videos matching [query].
  ///
  /// Returns up to [maxResults] items, each with:
  ///   videoId, title, channel, thumbnail
  ///
  /// Appends "karaoke" to the query and restricts to Music category (10)
  /// so movies / drama OSTs are filtered out.
  static Future<List<Map<String, String>>> searchKaraokeVideos({
    required String query,
    int maxResults = 10,
  }) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/search',
        {
          'part':            'snippet',
          'q':               '$query karaoke',
          'type':            'video',
          'videoCategoryId': '10',   // Music only — excludes movies/dramas
          'maxResults':      '$maxResults',
          'key':             apiKey,
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final items = body['items'] as List? ?? [];
        return items.map<Map<String, String>>((item) {
          final id      = (item['id']      as Map<String, dynamic>?)?['videoId']                      as String? ?? '';
          final snippet = item['snippet']  as Map<String, dynamic>? ?? {};
          final thumb   = (snippet['thumbnails'] as Map<String, dynamic>?)?['medium']
                              as Map<String, dynamic>?;
          return {
            'videoId':   id,
            'title':     snippet['title']        as String? ?? '',
            'channel':   snippet['channelTitle'] as String? ?? '',
            'thumbnail': thumb?['url']           as String? ?? '',
          };
        }).where((m) => m['videoId']!.isNotEmpty).toList();
      }
    } catch (_) {
      // Network error / timeout — return empty list
    }
    return [];
  }

  static Future<String?> _fetchFirstVideoId(String query) async {
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/youtube/v3/search',
        {
          'part': 'snippet',
          'q': query,
          'type': 'video',
          'maxResults': '1',
          'key': apiKey,
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body  = jsonDecode(res.body) as Map<String, dynamic>;
        final items = body['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final id = items[0]['id'] as Map<String, dynamic>?;
          final videoId = id?['videoId'] as String?;
          if (videoId != null && videoId.isNotEmpty) return videoId;
        }
      }
    } catch (_) {
      // Network error / timeout — fall through to return null
    }
    return null;
  }
}
