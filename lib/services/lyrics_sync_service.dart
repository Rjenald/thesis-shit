import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/youtube_karaoke_session.dart';

class LyricsSyncService {
  /// Get currently active lyric line index based on video time
  static int getCurrentLineIndex(
    Duration currentTime,
    List<TimedLyricLine> lyrics,
  ) {
    for (int i = 0; i < lyrics.length; i++) {
      if (lyrics[i].isActive(currentTime)) {
        return i;
      }
    }
    return -1;
  }

  /// Parse LRC format lyrics
  /// Format: [MM:SS.ms]Lyric text
  /// Example: [00:12.34]First line of lyrics
  static List<TimedLyricLine> parseLrcLyrics(String lrcContent) {
    final lines = <TimedLyricLine>[];
    final pattern = RegExp(r'\[(\d{2}):(\d{2}[.,]\d{2,3})\](.*?)$', multiLine: true);

    final matches = pattern.allMatches(lrcContent);

    for (int idx = 0; idx < matches.length; idx++) {
      final match = matches.elementAt(idx);

      try {
        final minutes = int.parse(match.group(1)!);
        final secondsStr = match.group(2)!.replaceAll(',', '.');
        final seconds = double.parse(secondsStr);
        final text = match.group(3)!.trim();

        if (text.isNotEmpty) {
          final startTime = Duration(
            milliseconds: (minutes * 60000 + seconds * 1000).toInt(),
          );

          // Estimate end time based on next lyric or 3 seconds
          Duration endTime;
          if (idx + 1 < matches.length) {
            final nextMatch = matches.elementAt(idx + 1);
            final nextMinutes = int.parse(nextMatch.group(1)!);
            final nextSecondsStr = nextMatch.group(2)!.replaceAll(',', '.');
            final nextSeconds = double.parse(nextSecondsStr);
            endTime = Duration(
              milliseconds: (nextMinutes * 60000 + nextSeconds * 1000).toInt(),
            );
          } else {
            endTime = startTime + const Duration(seconds: 3);
          }

          lines.add(TimedLyricLine(
            text: text,
            startTime: startTime,
            endTime: endTime,
          ));
        }
      } catch (e) {
        debugPrint('Error parsing lyric line: $e');
      }
    }

    return lines;
  }

  /// Fetch lyrics with timestamps from LrcLib
  static Future<List<TimedLyricLine>> fetchTimedLyricsFromLrcLib(
    String songTitle,
    String artist,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://lrclib.net/api/get?'
          'artist_name=${Uri.encodeComponent(artist)}&'
          'track_name=${Uri.encodeComponent(songTitle)}'
        ),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // Prefer synced lyrics (syncedLyrics) over plain lyrics
        final syncedLyrics = json['syncedLyrics'] as String?;
        final plainLyrics = json['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          return parseLrcLyrics(syncedLyrics);
        } else if (plainLyrics != null && plainLyrics.isNotEmpty) {
          // Fallback to plain lyrics (will need manual timing)
          return _createPlainLyricsWithTiming(plainLyrics);
        }
      }
    } catch (e) {
      debugPrint('Error fetching lyrics from LrcLib: $e');
    }

    return [];
  }

  /// Create timed lyrics from plain lyrics (auto-estimate timing)
  static List<TimedLyricLine> _createPlainLyricsWithTiming(
    String plainLyrics,
  ) {
    final lines = <TimedLyricLine>[];
    final textLines = plainLyrics.split('\n').where((l) => l.isNotEmpty).toList();

    const secondsPerLine = 3.5; // Estimate 3.5 seconds per line

    for (int i = 0; i < textLines.length; i++) {
      final startTime = Duration(
        milliseconds: (i * secondsPerLine * 1000).toInt(),
      );
      final endTime = Duration(
        milliseconds: ((i + 1) * secondsPerLine * 1000).toInt(),
      );

      lines.add(TimedLyricLine(
        text: textLines[i].trim(),
        startTime: startTime,
        endTime: endTime,
      ));
    }

    return lines;
  }

  /// Offset all lyrics by a duration (for sync adjustment)
  static List<TimedLyricLine> offsetLyrics(
    List<TimedLyricLine> lyrics,
    Duration offset,
  ) {
    return lyrics.map((lyric) {
      return TimedLyricLine(
        text: lyric.text,
        startTime: lyric.startTime + offset,
        endTime: lyric.endTime + offset,
        targetPitch: lyric.targetPitch,
      );
    }).toList();
  }

  /// Search lyrics from multiple sources
  static Future<List<TimedLyricLine>> searchLyrics(
    String title,
    String artist,
  ) async {
    // Try LrcLib first
    var lyrics = await fetchTimedLyricsFromLrcLib(title, artist);
    if (lyrics.isNotEmpty) return lyrics;

    // Additional fallback sources can be added here if needed

    return [];
  }
}
