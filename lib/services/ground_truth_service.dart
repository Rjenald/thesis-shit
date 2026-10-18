/// Loads the authored per-syllable ground-truth/target melody for a karaoke
/// song from assets/ground_truth/*.json — the intended note the singer is
/// supposed to sing, used as the comparison target for karaoke pitch
/// scoring. Only songs with a bundled ground-truth file support that
/// comparison; [loadForSong] returns null for everything else, and callers
/// must treat that as "no target available" rather than inventing one.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../core/note_utils.dart' show noteNameToFrequency;
import 'admin_media_service.dart';
import 'song_catalog_service.dart';

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
  /// Every song's ground truth is assets/ground_truth/<Title - Artist>.json,
  /// the same stem its backing track uses. Resolved from the catalog rather
  /// than a separate title-to-filename table, so there is one list of songs
  /// and no second table to drift out of step with it.
  static String? assetPathFor(String songTitle) {
    final name = SongCatalogService.assetNameFor(songTitle);
    return name == null ? null : 'assets/ground_truth/$name.json';
  }

  /// Whether this song ships with a ground-truth melody, ignoring any admin
  /// upload — lets the admin screen distinguish "using the built-in file"
  /// from "nothing available", which decides whether deleting an upload
  /// leaves the song with a working target melody.
  static bool hasBundledGroundTruth(String songTitle) =>
      assetPathFor(songTitle) != null;

  /// Returns the song's ground-truth syllables sorted by time, or null if
  /// no ground truth is available for it (not an error — most songs don't
  /// have one yet).
  static Future<List<GroundTruthSyllable>?> loadForSong(
    String songTitle,
  ) async {
    // An admin upload overrides the bundled file for this song, and is the
    // only source for a song the admin added — assets are read-only, so an
    // uploaded melody can never live in _assetBySongTitle.
    final uploadedPath = AdminMediaService.groundTruthPathFor(songTitle);
    final assetPath = assetPathFor(songTitle);
    if (uploadedPath == null && assetPath == null) return null;

    try {
      final raw = uploadedPath != null
          ? await File(uploadedPath).readAsString()
          : await rootBundle.loadString(assetPath!);
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
