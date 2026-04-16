import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/lyrics.dart';

/// Fetches real synced lyrics from LRCLIB (https://lrclib.net)
/// Free, no API key, supports OPM/Filipino songs.
class LrcLibService {
  static const _base = 'https://lrclib.net/api';
  static const _timeout = Duration(seconds: 8);

  /// Fetch synced lyrics for a song. Returns null on failure.
  static Future<List<LyricLine>?> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    try {
      final uri = Uri.parse('$_base/search').replace(queryParameters: {
        'track_name': title,
        'artist_name': artist,
      });

      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;

      final List data = json.decode(res.body);
      if (data.isEmpty) return null;

      // Pick the best match — prefer synced lyrics
      Map<String, dynamic> best = data.first as Map<String, dynamic>;
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        if (m['syncedLyrics'] != null &&
            (m['syncedLyrics'] as String).isNotEmpty) {
          best = m;
          break;
        }
      }

      final synced = best['syncedLyrics'] as String?;
      if (synced != null && synced.isNotEmpty) {
        return _parseSynced(synced);
      }

      // Fallback: plain lyrics with fixed 4s per line
      final plain = best['plainLyrics'] as String?;
      if (plain != null && plain.isNotEmpty) {
        return _parsePlain(plain);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse LRC-format synced lyrics into LyricLine list with durations.
  /// Format: [MM:SS.xx] Lyric text
  static List<LyricLine> _parseSynced(String lrc) {
    final lines = lrc.split('\n');
    final parsed = <({Duration time, String text})>[];

    final re = RegExp(r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$');

    for (final line in lines) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final ms = int.parse(m.group(3)!.padRight(3, '0'));
      final text = m.group(4)!.trim();
      parsed.add((
        time: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: text,
      ));
    }

    if (parsed.isEmpty) return [];

    // Convert timestamps to per-line durations
    final result = <LyricLine>[];
    for (int i = 0; i < parsed.length; i++) {
      final current = parsed[i];
      final next = i + 1 < parsed.length ? parsed[i + 1] : null;

      int durSeconds;
      if (next != null) {
        final diff = next.time - current.time;
        durSeconds = diff.inSeconds.clamp(1, 12);
      } else {
        durSeconds = 4; // last line
      }

      result.add(LyricLine(current.text, durSeconds));
    }

    return result;
  }

  /// Parse plain lyrics (no timestamps) — 4 seconds per line.
  static List<LyricLine> _parsePlain(String plain) {
    return plain
        .split('\n')
        .map((l) => l.trim())
        .map((l) => LyricLine(l, l.isEmpty ? 1 : 4))
        .toList();
  }
}
