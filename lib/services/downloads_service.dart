/// DownloadsService — persists a list of songs the user has "downloaded"
/// for offline karaoke use.
///
/// In this prototype the "download" is metadata-only (title + artist +
/// language stored in SharedPreferences).  The YouTube video is streamed at
/// play-time; this service simply lets the UI track and filter which songs the
/// user has marked as saved locally.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadsService {
  static const _key = 'huni_karaoke_downloads_v1';

  // ── In-memory cache (filled on first load) ────────────────────────────────
  static Set<String>? _keys; // "title||artist"

  static String _makeKey(String title, String artist) =>
      '${title.toLowerCase()}||${artist.toLowerCase()}';

  // ── Load ──────────────────────────────────────────────────────────────────

  static Future<Set<String>> _ensureLoaded() async {
    if (_keys != null) return _keys!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _keys = raw.toSet();
    return _keys!;
  }

  static Future<bool> isDownloaded(String title, String artist) async {
    final keys = await _ensureLoaded();
    return keys.contains(_makeKey(title, artist));
  }

  static Future<List<Map<String, String>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((entry) {
      final parts = entry.split('||');
      return {
        'title': parts.length > 2 ? parts[2] : '',
        'artist': parts.length > 3 ? parts[3] : '',
        'language': parts.length > 4 ? parts[4] : '',
      };
    }).toList();
  }

  // ── Download ──────────────────────────────────────────────────────────────

  static Future<void> download(
    String title,
    String artist,
    String language,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _ensureLoaded();
    final k = _makeKey(title, artist);
    if (keys.contains(k)) return; // already downloaded

    keys.add(k);
    // Store with full metadata so we can reconstruct the list later.
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(
      jsonEncode({'title': title, 'artist': artist, 'language': language}),
    );
    await prefs.setStringList(_key, raw);
    _keys = keys;
  }

  // ── Remove ────────────────────────────────────────────────────────────────

  static Future<void> remove(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _ensureLoaded();
    final k = _makeKey(title, artist);
    keys.remove(k);

    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((entry) {
      try {
        final m = jsonDecode(entry) as Map<String, dynamic>;
        return _makeKey(
              m['title'] as String? ?? '',
              m['artist'] as String? ?? '',
            ) ==
            k;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_key, raw);
    _keys = keys;
  }

  // ── Bulk-load set of keys (used by UI for fast isDownloaded checks) ────────

  static Future<Set<String>> loadKeySet() async => _ensureLoaded();

  static void invalidateCache() => _keys = null;
}
