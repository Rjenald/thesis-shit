import 'dart:convert';
import 'package:http/http.dart' as http;

/// Stingray Karaoke API (KAPI) service.
///
/// To activate: replace [apiKey] with the key you receive from Stingray.
/// Contact: https://www.stingray.com/streaming-distribution/formats/api-delivery/
///
/// When [apiKey] is empty the service returns null and the app falls back
/// to YouTube → Deezer automatically.
class StingrayService {
  // ── PUT YOUR STINGRAY API KEY HERE ────────────────────────────────────────
  static const String apiKey = ''; // e.g. 'sk_live_xxxxxxxxxxxx'
  // ─────────────────────────────────────────────────────────────────────────

  static const String _base = 'https://api.stingray.com/kapi/v1';
  static const _timeout = Duration(seconds: 10);

  static bool get hasKey => apiKey.isNotEmpty;

  /// Search for a karaoke track and return its audio stream URL.
  /// Returns null if no key or track not found.
  static Future<String?> getStreamUrl({
    required String title,
    required String artist,
  }) async {
    if (!hasKey) return null;

    try {
      // Search for the track
      final searchUri = Uri.parse('$_base/tracks/search').replace(
        queryParameters: {
          'q': '$title $artist',
          'limit': '5',
          'apiKey': apiKey,
        },
      );

      final searchRes = await http
          .get(searchUri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (searchRes.statusCode != 200) return null;

      final data = json.decode(searchRes.body);
      final tracks = (data['tracks'] ?? data['data'] ?? data['results']) as List?;
      if (tracks == null || tracks.isEmpty) return null;

      // Get best matching track
      final track = tracks.first;
      final trackId = track['id']?.toString() ?? track['trackId']?.toString();
      if (trackId == null) return null;

      // Get stream URL for that track
      final streamUri = Uri.parse('$_base/tracks/$trackId/stream').replace(
        queryParameters: {'apiKey': apiKey},
      );

      final streamRes = await http
          .get(streamUri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (streamRes.statusCode != 200) return null;

      final streamData = json.decode(streamRes.body);
      return streamData['url']?.toString() ??
          streamData['streamUrl']?.toString() ??
          streamData['audioUrl']?.toString();
    } catch (_) {
      return null;
    }
  }
}
