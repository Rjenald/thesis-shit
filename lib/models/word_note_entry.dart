/// One word from a "without karaoke" recording, paired with the musical
/// note detected while it was sung.
class WordNoteEntry {
  final String word;

  /// Note name, e.g. "A4", "C#5". Null if no confident pitch was detected
  /// during this word's time window (spoken softly, drowned in noise, etc.).
  final String? note;

  final int startTimeMs;
  final int endTimeMs;

  const WordNoteEntry({
    required this.word,
    required this.note,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'note': note,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
      };

  factory WordNoteEntry.fromJson(Map<String, dynamic> j) => WordNoteEntry(
        word: j['word'] as String? ?? '',
        note: j['note'] as String?,
        startTimeMs: j['startTimeMs'] as int? ?? 0,
        endTimeMs: j['endTimeMs'] as int? ?? 0,
      );
}
