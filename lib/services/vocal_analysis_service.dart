/// VocalAnalysisService — derives high-level "how was that take?" stats
/// from a list of WordAnalysis results.
///
/// Per the spec we deliberately DO NOT score correctness against a target
/// melody. We only describe what was sung, not whether it was "right".
library;

import 'dart:math';
import 'word_note_sync_service.dart';

class VocalSummary {
  final double averageConfidence;   // 0..1 — overall CREPE clarity
  final double pitchStability;      // 0..1 — 1 = very steady, 0 = wobbly
  final double vocalConsistency;    // 0..1 — fraction of words that produced notes
  final int transitions;            // number of note changes across the take

  const VocalSummary({
    required this.averageConfidence,
    required this.pitchStability,
    required this.vocalConsistency,
    required this.transitions,
  });

  int get clarityPct     => (averageConfidence * 100).round();
  int get stabilityPct   => (pitchStability    * 100).round();
  int get consistencyPct => (vocalConsistency  * 100).round();
}

class VocalAnalysisService {
  static VocalSummary analyze(List<WordAnalysis> results) {
    if (results.isEmpty) {
      return const VocalSummary(
        averageConfidence: 0,
        pitchStability:    0,
        vocalConsistency:  0,
        transitions:       0,
      );
    }

    // ── Average CREPE confidence across all words that had a signal ────────
    final confidentWords = results.where((w) => w.confidence > 0).toList();
    final avgConf = confidentWords.isEmpty
        ? 0.0
        : confidentWords.map((w) => w.confidence).reduce((a, b) => a + b) /
            confidentWords.length;

    // ── Vocal consistency: how many words landed at least one note ─────────
    final consistency = results.where((w) => w.hasNotes).length /
        results.length.toDouble();

    // ── Pitch stability: inverse of how often the note changes WITHIN words
    // A word like "Hello" with notes [G4, G4, G4, A4] = 1 change in 4 frames
    // → stability 0.75. We average per word.
    double stabilitySum = 0;
    int stabilityCount = 0;
    for (final w in results) {
      if (w.notes.length <= 1) {
        // 0 or 1 note → considered fully stable (or unknown)
        if (w.hasNotes) {
          stabilitySum += 1.0;
          stabilityCount++;
        }
        continue;
      }
      final changes = w.notes.length - 1;
      // Map "1 change per word" → 0.9 stability, "5+ changes" → near 0.
      final s = max(0.0, 1.0 - (changes / 5.0));
      stabilitySum += s;
      stabilityCount++;
    }
    final stability = stabilityCount == 0 ? 0.0 : stabilitySum / stabilityCount;

    // ── Total note transitions across all words ────────────────────────────
    final transitions =
        results.fold<int>(0, (acc, w) => acc + max(0, w.notes.length - 1));

    return VocalSummary(
      averageConfidence: avgConf,
      pitchStability:    stability,
      vocalConsistency:  consistency,
      transitions:       transitions,
    );
  }
}