import 'word_note_entry.dart';

/// A completed reference-free recording: the word-by-word note summary
/// produced by running speech-to-text and pitch detection over the full
/// take after the fact, with no reference melody to score against.
///
/// Covers both modes that work this way — Freestyle Karaoke (no song at
/// all) and Search & Sing (a song found online, so there are words and
/// usually a backing track, but still no authored ground-truth melody).
/// [songTitle] is what separates them, and the library lists them under
/// their own sections because they are different things to look back on:
/// one is "how did I sing this song", the other is "what did I sing".
class FreestyleSummary {
  final String id;
  final DateTime createdAt;
  final int durationSeconds;

  /// Same reference scheme as [RecordingEntry.filePath] — either
  /// `local:<id>` (WAV stored as base64 in SharedPreferences under
  /// `wav_<id>`) or a real filesystem path.
  final String audioRef;

  /// The song sung in Search & Sing, null in Freestyle. Null is also what
  /// every recording made before this field existed decodes to, so an old
  /// library entry keeps working and simply lists as Freestyle.
  final String? songTitle;
  final String? songArtist;

  final List<WordNoteEntry> words;

  const FreestyleSummary({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.audioRef,
    required this.words,
    this.songTitle,
    this.songArtist,
  });

  /// True when this came from Search & Sing rather than Freestyle.
  bool get isSearchAndSing =>
      songTitle != null && songTitle!.trim().isNotEmpty;

  /// What to show as this recording's name.
  String get displayTitle =>
      isSearchAndSing ? songTitle!.trim() : 'Freestyle recording';

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'audioRef': audioRef,
        'words': words.map((w) => w.toJson()).toList(),
        if (songTitle != null) 'songTitle': songTitle,
        if (songArtist != null) 'songArtist': songArtist,
      };

  factory FreestyleSummary.fromJson(Map<String, dynamic> j) => FreestyleSummary(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        durationSeconds: j['durationSeconds'] as int? ?? 0,
        audioRef: j['audioRef'] as String? ?? '',
        songTitle: j['songTitle'] as String?,
        songArtist: j['songArtist'] as String?,
        words: (j['words'] as List<dynamic>? ?? [])
            .map((w) => WordNoteEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}
