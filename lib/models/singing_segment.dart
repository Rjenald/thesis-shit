import '../core/note_utils.dart' show PitchFeedback;

/// One ground-truth syllable's target-vs-actual pitch comparison — the
/// karaoke equivalent of [WordNoteEntry] in "without karaoke" mode, but
/// anchored to a real reference melody instead of just the user's own
/// voice: [targetNote]/[targetFrequency] come from the song's authored
/// ground truth, [actualNote]/[actualFrequency] come from the user's own
/// CREPE analysis, and [status] is how they compare.
///
/// [status] reuses [PitchFeedback] (correct/tooHigh/tooLow/noSignal) —
/// correct = in tune, tooHigh = sharp, tooLow = flat, noSignal = no
/// reliable pitch was detected near this syllable (silence, unvoiced
/// speech, or low CREPE confidence) — never conflated with sharp/flat.
class SingingSegment {
  /// The ground-truth reference syllable — what the singer was *supposed*
  /// to sing at this point. Kept for the detail view's "Expected" row; the
  /// main timeline shows [actualWord] instead, since that's what the user
  /// actually sang.
  final String syllable;
  final int startTimeMs;
  final int endTimeMs;

  final String targetNote;
  final double targetFrequency;

  /// What Whisper actually recognized around this time window — the real
  /// answer to "what did I sing here?", independent of [syllable]. Null if
  /// no recognized word overlaps this window closely enough to attribute.
  final String? actualWord;

  /// Which recognized-word OCCURRENCE this syllable belongs to (an index
  /// into the transcription's word list from the analysis that built it).
  ///
  /// Identity, not text — and that distinction is the whole point: several
  /// consecutive ground-truth syllables sharing ONE occurrence are one
  /// lyric that must be displayed once, however many pitch frames or
  /// syllables it spans, while a singer who genuinely repeats a word
  /// produces two occurrences with identical [actualWord] text that must
  /// both be shown. Grouping on the text alone cannot tell those apart.
  /// Null when no word was attributed, or for sessions saved before this
  /// was recorded (callers fall back to text comparison then).
  final int? actualWordIndex;

  /// Null when no confident CREPE pitch was found for this syllable.
  final String? actualNote;
  final double? actualFrequency;

  /// Signed cents: 1200 * log2(actualFrequency / targetFrequency).
  /// Positive = sharp, negative = flat. Null alongside [actualFrequency].
  final double? differenceCents;

  final PitchFeedback status;

  /// CREPE confidence backing [actualFrequency] (0 when [status] is
  /// [PitchFeedback.noSignal]).
  final double confidence;

  /// The raw CREPE frame frequencies (Hz) that went into [actualFrequency]
  /// — preserved so the detail view can show how pitch actually moved
  /// during this syllable (e.g. vibrato, a slide) instead of only the
  /// single summarized value. Deliberately NOT persisted in [toJson]: it's
  /// only populated fresh right after analysis, on the same session that
  /// produced it — a session reloaded from the library (see [fromJson])
  /// just won't have a mini pitch-movement view, which is an acceptable,
  /// clearly-scoped gap rather than bloating every saved session with raw
  /// frame data for its whole syllable-by-syllable history.
  final List<double> frameFrequencies;

  const SingingSegment({
    required this.syllable,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.targetNote,
    required this.targetFrequency,
    this.actualWord,
    this.actualWordIndex,
    required this.actualNote,
    required this.actualFrequency,
    required this.differenceCents,
    required this.status,
    required this.confidence,
    this.frameFrequencies = const [],
  });

  Map<String, dynamic> toJson() => {
        'syllable': syllable,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'targetNote': targetNote,
        'targetFrequency': targetFrequency,
        'actualWord': actualWord,
        'actualWordIndex': actualWordIndex,
        'actualNote': actualNote,
        'actualFrequency': actualFrequency,
        'differenceCents': differenceCents,
        'status': status.name,
        'confidence': confidence,
      };

  factory SingingSegment.fromJson(Map<String, dynamic> j) => SingingSegment(
        syllable: j['syllable'] as String? ?? '',
        startTimeMs: j['startTimeMs'] as int? ?? 0,
        endTimeMs: j['endTimeMs'] as int? ?? 0,
        targetNote: j['targetNote'] as String? ?? '',
        targetFrequency: (j['targetFrequency'] as num?)?.toDouble() ?? 0,
        actualWord: j['actualWord'] as String?,
        actualWordIndex: j['actualWordIndex'] as int?,
        actualNote: j['actualNote'] as String?,
        actualFrequency: (j['actualFrequency'] as num?)?.toDouble(),
        differenceCents: (j['differenceCents'] as num?)?.toDouble(),
        status: PitchFeedback.values.firstWhere(
          (v) => v.name == j['status'],
          orElse: () => PitchFeedback.noSignal,
        ),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Data-driven performance stats for a karaoke session's [SingingSegment]s
/// — the source of truth for the result screen's summary header. Kept as
/// plain computation separate from any widget so it's reusable later for
/// coaching suggestions, problem-note detection, or MAPEH-style reports
/// without redoing this logic.
///
/// Only segments with a detected pitch count toward the percentages —
/// silence/no-signal segments are excluded from the denominator entirely,
/// never folded into "flat".
class SingingPerformanceSummary {
  final int totalSegments;
  final int validSegments;
  final int inTuneCount;
  final int sharpCount;
  final int flatCount;
  final int noSignalCount;

  const SingingPerformanceSummary({
    required this.totalSegments,
    required this.validSegments,
    required this.inTuneCount,
    required this.sharpCount,
    required this.flatCount,
    required this.noSignalCount,
  });

  factory SingingPerformanceSummary.fromSegments(
    List<SingingSegment> segments,
  ) {
    var inTune = 0, sharp = 0, flat = 0, noSignal = 0;
    for (final s in segments) {
      switch (s.status) {
        case PitchFeedback.correct:
          inTune++;
          break;
        case PitchFeedback.tooHigh:
          sharp++;
          break;
        case PitchFeedback.tooLow:
          flat++;
          break;
        case PitchFeedback.noSignal:
          noSignal++;
          break;
      }
    }
    return SingingPerformanceSummary(
      totalSegments: segments.length,
      validSegments: inTune + sharp + flat,
      inTuneCount: inTune,
      sharpCount: sharp,
      flatCount: flat,
      noSignalCount: noSignal,
    );
  }

  double get inTunePercent => validSegments == 0 ? 0 : inTuneCount / validSegments * 100;
  double get sharpPercent => validSegments == 0 ? 0 : sharpCount / validSegments * 100;
  double get flatPercent => validSegments == 0 ? 0 : flatCount / validSegments * 100;

  /// How much of the recorded window actually had a detectable pitch, out
  /// of every ground-truth syllable in it — separate from [inTunePercent]
  /// on purpose: a handful of well-sung syllables out of hundreds would
  /// otherwise still read as a confident "100% in tune" with no indication
  /// that almost none of the song was actually covered.
  double get coveragePercent =>
      totalSegments == 0 ? 0 : validSegments / totalSegments * 100;

  bool get hasData => validSegments > 0;
}
