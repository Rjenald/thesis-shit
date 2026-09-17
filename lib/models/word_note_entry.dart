/// One word from a "without karaoke" recording, paired with the musical
/// note(s) detected while it was sung — one entry per syllable in [word],
/// so a multi-syllable word shows a note per syllable rather than a single
/// blended note for the whole word.
class WordNoteEntry {
  final String word;

  /// One note name per syllable in [word], in order (e.g. "A4", "C#5").
  /// A null entry means no confident pitch was found for that syllable
  /// (spoken softly, drowned in noise, etc.) — always has at least 1 entry.
  final List<String?> syllableNotes;

  final int startTimeMs;
  final int endTimeMs;

  const WordNoteEntry({
    required this.word,
    required this.syllableNotes,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'syllableNotes': syllableNotes,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
      };

  factory WordNoteEntry.fromJson(Map<String, dynamic> j) {
    final rawSyllables = j['syllableNotes'] as List<dynamic>?;
    final syllableNotes = rawSyllables != null
        ? rawSyllables.map((e) => e as String?).toList()
        // Older saved summaries (before per-syllable notes) stored a single
        // 'note' field — read it as a one-syllable list so old library
        // entries still load instead of crashing.
        : <String?>[j['note'] as String?];

    return WordNoteEntry(
      word: j['word'] as String? ?? '',
      syllableNotes: syllableNotes.isEmpty ? [null] : syllableNotes,
      startTimeMs: j['startTimeMs'] as int? ?? 0,
      endTimeMs: j['endTimeMs'] as int? ?? 0,
    );
  }
}
