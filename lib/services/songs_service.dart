/// SongsService — fetches the OPM song catalog from the CREPE backend.
///
/// Falls back to the local [TagalogBisayaSongs] database (1 000+ songs) when
/// the backend is unreachable (offline / server not running).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/pitch_server_config.dart';
import '../data/tagalog_bisaya_songs.dart';

class SongsService {
  static const _timeout = Duration(seconds: 5);

  // In-memory cache so we only fetch once per app session.
  static List<Map<String, String>>? _cache;
  static bool _fromBackend = false;

  /// Returns [true] if the last successful load came from the backend server.
  static bool get isFromBackend => _fromBackend;

  /// The full local song list (1 000+ songs) as Map entries.
  ///
  /// Derived from [TagalogBisayaSongs.songs] — single source of truth for all
  /// karaoke pages across normal user, teacher, and student accounts.
  static List<Map<String, String>> get _localSongs {
    return TagalogBisayaSongs.songs
        .map<Map<String, String>>(
          (s) => {
            'title': s.title,
            'artist': s.artist,
            'language': s.language,
            'image': '', // no static thumbnail; UI falls back to icon
          },
        )
        .toList();
  }

  /// Fetch songs from the CREPE backend.
  /// Falls back to the local 1 000-song database if the server is unreachable.
  static Future<List<Map<String, String>>> fetchSongs({
    String? language,
    bool forceRefresh = false,
  }) async {
    if (_cache != null && !forceRefresh) return _applyFilter(_cache!, language);

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
            .map<Map<String, String>>(
              (m) => m.map((k, v) => MapEntry(k, v?.toString() ?? '')),
            )
            .toList();

        _cache = songs;
        _fromBackend = true;
        return _applyFilter(songs, language);
      }
    } catch (_) {
      // Server unreachable — fall through to local database.
    }

    // ── Local fallback: full 1 000-song database ────────────────────────────
    _fromBackend = false;
    final local = _localSongs;
    _cache = local;
    return _applyFilter(local, language);
  }

  static List<Map<String, String>> _applyFilter(
    List<Map<String, String>> songs,
    String? language,
  ) {
    if (language == null) return songs;
    final lang = language.toLowerCase();
    return songs
        .where((s) => (s['language'] ?? '').toLowerCase() == lang)
        .toList();
  }

  /// Clear the cache so the next call re-fetches from the backend.
  static void clearCache() {
    _cache = null;
    _fromBackend = false;
  }
}
