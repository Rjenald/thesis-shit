/// Loads the authored per-syllable ground-truth/target melody for a karaoke
/// song from assets/ground_truth/*.json — the intended note the singer is
/// supposed to sing, used as the comparison target for karaoke pitch
/// scoring. Only songs with a bundled ground-truth file support that
/// comparison; [loadForSong] returns null for everything else, and callers
/// must treat that as "no target available" rather than inventing one.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/note_utils.dart' show noteNameToFrequency;

/// One authored ground-truth syllable: the note the singer is meant to hit
/// during [startTime]–[endTime] in the song's own timeline (i.e. the same
/// clock as song playback position, not relative to when recording started).
class GroundTruthSyllable {
  final String syllable;
  final Duration startTime;
  final Duration endTime;
  final String noteName;
  final double frequency;

  const GroundTruthSyllable({
    required this.syllable,
    required this.startTime,
    required this.endTime,
    required this.noteName,
    required this.frequency,
  });
}

class GroundTruthService {
  // Song title (lowercased) -> bundled ground-truth asset. Only songs
  // listed here have a real target melody; add more as files are authored.
  static const Map<String, String> _assetBySongTitle = {
    'nasa iyo na ang lahat': 'assets/ground_truth/Nasa_Iyo_Na_Ang_Lahat.json',
  };

  /// Returns the song's ground-truth syllables sorted by time, or null if
  /// no ground truth is available for it (not an error — most songs don't
  /// have one yet).
  static Future<List<GroundTruthSyllable>?> loadForSong(
    String songTitle,
  ) async {
    final assetPath = _assetBySongTitle[songTitle.toLowerCase()];
    if (assetPath == null) return null;

    try {
      final raw = await rootBundle.loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];

      final syllables = <GroundTruthSyllable>[];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        final noteName = m['note'] as String? ?? '';
        final frequency = noteNameToFrequency(noteName);
        if (frequency == null) continue; // unparseable entry — skip, don't crash

        final startSec = (m['start'] as num?)?.toDouble();
        final endSec = (m['end'] as num?)?.toDouble();
        if (startSec == null || endSec == null || endSec <= startSec) continue;

        syllables.add(GroundTruthSyllable(
          syllable: m['syllable'] as String? ?? '',
          startTime: Duration(milliseconds: (startSec * 1000).round()),
          endTime: Duration(milliseconds: (endSec * 1000).round()),
          noteName: noteName,
          frequency: frequency,
        ));
      }
      syllables.sort((a, b) => a.startTime.compareTo(b.startTime));
      return syllables;
    } catch (e) {
      debugPrint('Failed to load ground truth for "$songTitle": $e');
      return null;
    }
  }
}
