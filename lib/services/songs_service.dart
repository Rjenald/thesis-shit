/// SongsService — fetches the OPM song catalog from the CREPE backend.
///
/// Falls back to the local [kAllSongs] constant when the backend is
/// unreachable (offline / server not running).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/pitch_server_config.dart';
import '../data/songs_data.dart';

class SongsService {
  static const _timeout = Duration(seconds: 5);

  // In-memory cache so we only fetch once per app session.
  static List<Map<String, String>>? _cache;
  static bool _fromBackend = false;

  /// Returns [true] if the last successful load came from the backend server.
  static bool get isFromBackend => _fromBackend;

  /// Fetch songs from the CREPE backend.
  /// Falls back to [kAllSongs] if the server is unreachable.
  static Future<List<Map<String, String>>> fetchSongs({
    String? language,
    bool forceRefresh = false,
  }) async {
    if (_cache != null && !forceRefresh) return _cache!;

    try {
      final uri = Uri.parse(PitchServerConfig.songsUrl).replace(
        queryParameters: language != null ? {'language': language} : null,
      );

      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final raw = (body['songs'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        final songs = raw
            .map<Map<String, String>>((m) => m.map(
                  (k, v) => MapEntry(k, v?.toString() ?? ''),
                ))
            .toList();

        _cache = songs;
        _fromBackend = true;
        return songs;
      }
    } catch (_) {
      // Server unreachable — use local fallback silently
    }

    // ── Local fallback ──────────────────────────────────────────────────────
    _fromBackend = false;
    final fallback = language != null
        ? kAllSongs
            .where((s) =>
                (s['language'] ?? '').toLowerCase() == language.toLowerCase())
            .toList()
        : kAllSongs;

    _cache = fallback;
    return fallback;
  }

  /// Clear the cache so the next call re-fetches from the backend.
  static void clearCache() {
    _cache = null;
    _fromBackend = false;
  }
}
