import 'dart:convert';
import 'package:http/http.dart' as http;

/// One timed line from an LRC file.
class LrcLine {
  final Duration timestamp;
  final String text;
  const LrcLine({required this.timestamp, required this.text});
}

/// Fetches synchronized lyrics from lrclib.net (free, no API key required).
class LyricsService {
  static const _base = 'https://lrclib.net/api/get';

  /// Returns a list of timestamped lyric lines, or [] if not found.
  static Future<List<LrcLine>> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'track_name': title,
        'artist_name': artist,
      });
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
          m.group(3)!.padRight(2, '0').substring(0, 2));
      final ms = (minutes * 60 + seconds) * 1000 + hundredths * 10;
      final text = m.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      lines.add(LrcLine(
        timestamp: Duration(milliseconds: ms),
        text: text,
      ));
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }
}
