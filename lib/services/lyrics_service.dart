import 'dart:convert';
import 'package:http/http.dart' as http;

/// One timed line from an LRC file.
class LrcLine {
  final Duration timestamp;
  final String text;
  const LrcLine({required this.timestamp, required this.text});
}

/// One song found by searching lrclib — enough to show a result row and,
/// if picked, to sing along to.
class OnlineSongResult {
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  /// Timed lyric lines, empty when this match only has plain (untimed)
  /// lyrics — those can still be sung along to, just without the
  /// line-by-line highlight.
  final List<LrcLine> syncedLyrics;

  const OnlineSongResult({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.syncedLyrics,
  });

  bool get hasSyncedLyrics => syncedLyrics.isNotEmpty;
}

/// Fetches synchronized lyrics from lrclib.net (free, no API key required).
class LyricsService {
  static const _base = 'https://lrclib.net/api/get';
  static const _searchBase = 'https://lrclib.net/api/search';

  /// Searches lrclib for songs matching [query]. Returns [] on any failure
  /// (offline, timeout, bad response) — the caller shows an empty state
  /// rather than an error the user can't act on.
  static Future<List<OnlineSongResult>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(_searchBase)
          .replace(queryParameters: {'q': query.trim()});
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'Huni Karaoke (thesis project)'},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];

      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((t) {
            final synced = t['syncedLyrics'] as String?;
            return OnlineSongResult(
              title: t['trackName'] as String? ?? '',
              artist: t['artistName'] as String? ?? '',
              album: t['albumName'] as String? ?? '',
              duration: Duration(
                  seconds: ((t['duration'] as num?) ?? 0).round()),
              syncedLyrics:
                  synced == null || synced.isEmpty ? const [] : _parseLrc(synced),
            );
          })
          .where((s) => s.title.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns a list of timestamped lyric lines, or [] if not found.
  static Future<List<LrcLine>> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final uri = Uri.parse(
        _base,
      ).replace(queryParameters: {'track_name': title, 'artist_name': artist});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final synced = json['syncedLyrics'] as String?;
      if (synced == null || synced.isEmpty) return [];
      return _parseLrc(synced);
    } catch (_) {
      return [];
    }
  }

  /// Parses LRC text → list of LrcLine sorted by timestamp.
  /// Format: [mm:ss.xx] line text
  static List<LrcLine> _parseLrc(String lrc) {
    final lines = <LrcLine>[];
    final re = RegExp(r'\[(\d+):(\d+)\.(\d+)\](.*)');
    for (final raw in lrc.split('\n')) {
      final m = re.firstMatch(raw.trim());
      if (m == null) continue;
      final minutes = int.parse(m.group(1)!);
      final seconds = int.parse(m.group(2)!);
      final hundredths = int.parse(
        m.group(3)!.padRight(2, '0').substring(0, 2),
      );
      final ms = (minutes * 60 + seconds) * 1000 + hundredths * 10;
      final text = m.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      lines.add(
        LrcLine(
          timestamp: Duration(milliseconds: ms),
          text: text,
        ),
      );
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
