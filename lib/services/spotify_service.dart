/// SpotifyService — search tracks and fetch 30-second preview URLs.
///
/// Uses the Spotify Web API with Client Credentials flow (no user login).
/// Register your app at https://developer.spotify.com/dashboard to get your
/// Client ID and Client Secret, then replace the values below.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

// ── Spotify App Credentials ────────────────────────────────────────────────────
// Register at: https://developer.spotify.com/dashboard
class SpotifyConfig {
  static const clientId = 'YOUR_SPOTIFY_CLIENT_ID';
  static const clientSecret = 'YOUR_SPOTIFY_CLIENT_SECRET';
}

// ── Data Model ────────────────────────────────────────────────────────────────

class SpotifyTrack {
  final String id;
  final String title;
  final String artist;
  final String? albumArt; // URL to album cover image
  final String? previewUrl; // 30-second MP3 clip (can be null)
  final int durationMs;

  const SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    this.previewUrl,
    required this.durationMs,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artists =
        (json['artists'] as List?)?.map((a) => a['name'] as String).join(', ') ?? '';
    final images = json['album']?['images'] as List?;
    final art = images != null && images.isNotEmpty
        ? images.first['url'] as String?
        : null;
    return SpotifyTrack(
      id: json['id'] as String? ?? '',
      title: json['name'] as String? ?? 'Unknown',
      artist: artists,
      albumArt: art,
      previewUrl: json['preview_url'] as String?,
      durationMs: json['duration_ms'] as int? ?? 0,
    );
  }

  String get durationLabel {
    final m = (durationMs ~/ 60000).toString().padLeft(2, '0');
    final s = ((durationMs ~/ 1000) % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class SpotifyService {
  String? _accessToken;
  DateTime? _tokenExpiry;

  bool get _tokenValid =>
      _accessToken != null &&
      _tokenExpiry != null &&
      DateTime.now().isBefore(_tokenExpiry!);

  /// Fetch or refresh the Client Credentials access token.
  Future<bool> authenticate() async {
    if (_tokenValid) return true;

    try {
      final credentials = base64Encode(
          utf8.encode('${SpotifyConfig.clientId}:${SpotifyConfig.clientSecret}'));

      final res = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final data = json.decode(res.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String?;
      final expiresIn = data['expires_in'] as int? ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  /// Search Spotify for tracks matching [query].
  /// Returns up to [limit] results.
  Future<List<SpotifyTrack>> searchTracks(String query,
      {int limit = 20}) async {
    if (!await authenticate()) return [];

    try {
      final encoded = Uri.encodeQueryComponent(query);
      final res = await http.get(
        Uri.parse(
            'https://api.spotify.com/v1/search?q=$encoded&type=track&limit=$limit'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];

      final data = json.decode(res.body) as Map<String, dynamic>;
      final items =
          (data['tracks']?['items'] as List?) ?? [];
      return items
          .map((item) => SpotifyTrack.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Get a single track by Spotify ID.
  Future<SpotifyTrack?> getTrack(String trackId) async {
    if (!await authenticate()) return null;
    try {
      final res = await http.get(
        Uri.parse('https://api.spotify.com/v1/tracks/$trackId'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return SpotifyTrack.fromJson(
          json.decode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

// Singleton instance
final spotifyService = SpotifyService();
