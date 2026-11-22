import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How often each song gets picked to sing in Search & Sing.
///
/// This is demand data: the songs people actually want are the ones worth
/// spending authoring effort on, so the admin screen can rank them and the
/// next hand-authored ground truth goes to a song someone asked for rather
/// than a guess.
///
/// A count is recorded when a song is *chosen to sing*, not on every
/// keystroke — "nas" and "nasa" while typing are one intent, not two, and
/// counting partial queries would bury the real signal in noise.
class SongSearchStatsService {
  SongSearchStatsService._();

  static const _key = 'huni_song_search_stats_v1';

  static String _id(String title, String artist) =>
      '${title.trim().toLowerCase()}|${artist.trim().toLowerCase()}';

  /// Records one pick of [title] by [artist].
  static Future<void> recordPick(String title, String artist) async {
    if (title.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stats = _decode(prefs.getString(_key));
      final id = _id(title, artist);
      final existing = stats[id];

      stats[id] = SongSearchStat(
        title: title.trim(),
        artist: artist.trim(),
        count: (existing?.count ?? 0) + 1,
        lastSearchedAt: DateTime.now(),
      );

      await prefs.setString(
        _key,
        jsonEncode(stats.map((k, v) => MapEntry(k, v.toJson()))),
      );
    } catch (e) {
      // Analytics must never break singing — the user picked a song and
      // that's what matters.
      debugPrint('Could not record song pick: $e');
    }
  }

  /// Every tracked song, most-picked first.
  static Future<List<SongSearchStat>> mostSearched() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stats = _decode(prefs.getString(_key)).values.toList();
      stats.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return b.lastSearchedAt.compareTo(a.lastSearchedAt);
      });
      return stats;
    } catch (e) {
      debugPrint('Could not read song search stats: $e');
      return const [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, SongSearchStat> _decode(String? raw) {
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) =>
        MapEntry(k, SongSearchStat.fromJson(v as Map<String, dynamic>)));
  }
}

class SongSearchStat {
  final String title;
  final String artist;
  final int count;
  final DateTime lastSearchedAt;

  const SongSearchStat({
    required this.title,
    required this.artist,
    required this.count,
    required this.lastSearchedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'count': count,
        'lastSearchedAt': lastSearchedAt.toIso8601String(),
      };

  factory SongSearchStat.fromJson(Map<String, dynamic> j) => SongSearchStat(
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        count: j['count'] as int? ?? 0,
        lastSearchedAt:
            DateTime.tryParse(j['lastSearchedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}
