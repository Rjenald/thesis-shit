import 'word_note_entry.dart';

/// A completed "without karaoke" recording: the word-by-word note summary
/// produced by running speech-to-text and pitch detection over the full
/// take after the fact, with no reference song to score against.
class FreeSingSummary {
  final String id;
  final DateTime createdAt;
  final int durationSeconds;

  /// Same reference scheme as [RecordingEntry.filePath] — either
  /// `local:<id>` (WAV stored as base64 in SharedPreferences under
  /// `wav_<id>`) or a real filesystem path.
  final String audioRef;

  final List<WordNoteEntry> words;

  const FreeSingSummary({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.audioRef,
    required this.words,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'audioRef': audioRef,
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory FreeSingSummary.fromJson(Map<String, dynamic> j) => FreeSingSummary(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        durationSeconds: j['durationSeconds'] as int? ?? 0,
        audioRef: j['audioRef'] as String? ?? '',
        words: (j['words'] as List<dynamic>? ?? [])
            .map((w) => WordNoteEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}
