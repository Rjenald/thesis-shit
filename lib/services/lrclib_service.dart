import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/lyrics.dart';

/// Fetches real synced lyrics from LRCLIB (https://lrclib.net)
/// Falls back to lyrics.ovh for songs not in LRCLIB.
/// Free, no API key, supports OPM/Filipino/Bisaya songs.
class LrcLibService {
  static const _lrcBase = 'https://lrclib.net/api';
  static const _ovhBase = 'https://api.lyrics.ovh/v1';
  static const _timeout = Duration(seconds: 8);

  /// Fetch lyrics for a song.
  /// Priority: LRCLIB synced → LRCLIB plain → lyrics.ovh → null
  static Future<List<LyricLine>?> fetchLyrics({
    required String title,
    required String artist,
  }) async {
    // 1. Try LRCLIB (has synced timestamps)
    final lrcLib = await _fetchFromLrcLib(title: title, artist: artist);
    if (lrcLib != null) return lrcLib;

    // 2. Fallback: lyrics.ovh (plain text, broad coverage including OPM/Bisaya)
    final ovh = await _fetchFromLyricsOvh(title: title, artist: artist);
    if (ovh != null) return ovh;

    return null;
  }

  // ── LRCLIB ─────────────────────────────────────────────────────────────────

  static Future<List<LyricLine>?> _fetchFromLrcLib({
    required String title,
    required String artist,
  }) async {
    try {
      final uri = Uri.parse('$_lrcBase/search').replace(queryParameters: {
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

  // ── lyrics.ovh ─────────────────────────────────────────────────────────────

  static Future<List<LyricLine>?> _fetchFromLyricsOvh({
    required String title,
    required String artist,
  }) async {
    try {
      final artistEnc = Uri.encodeComponent(artist);
      final titleEnc = Uri.encodeComponent(title);
      final url = Uri.parse('$_ovhBase/$artistEnc/$titleEnc');

      final res = await http.get(url).timeout(_timeout);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final lyrics = data['lyrics'] as String?;
      if (lyrics == null || lyrics.trim().isEmpty) return null;

      return _parsePlain(lyrics);
    } catch (_) {
      return null;
    }
  }

  // ── Parsers ─────────────────────────────────────────────────────────────────

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

    // ── Intro padding ──────────────────────────────────────────────────────
    // If the first lyric starts after 3 s (e.g. [00:15.00]) add a silent
    // placeholder so the timer waits for the music intro before lyrics appear.
    final firstLineStart = parsed.first.time.inMilliseconds / 1000.0;
    if (firstLineStart > 3) {
      result.add(LyricLine('', firstLineStart.round().clamp(1, 120)));
    }

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
