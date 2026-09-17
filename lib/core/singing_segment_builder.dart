/// Combines a song's ground-truth melody with a batch CREPE pitch pass over
/// the user's recording into a time-aligned target-vs-actual comparison —
/// see [buildSingingSegments]. This is the karaoke analogue of
/// [buildWordNotes] in "without karaoke" mode, except the target here is a
/// real reference melody (assets/ground_truth/*.json via
/// GroundTruthService), not just the user's own voice.
library;

import '../models/singing_segment.dart';
import '../services/ground_truth_service.dart' show GroundTruthSyllable;
import '../services/lyrics_service.dart' show LrcLine;
import 'lyric_alignment_service.dart' show TranscribedWord;
import 'note_utils.dart';

/// For each ground-truth syllable that overlaps the recorded window
/// [recordStartOffset, recordEndOffset], finds the CREPE pitch frames that
/// fall in/near its time interval and compares their representative pitch
/// against the syllable's target frequency — and separately, finds
/// whichever Whisper-[recognizedWords] word overlaps that same window, so
/// the result can show what the singer actually said/sang there, not just
/// the reference syllable they were supposed to sing.
///
/// Ground-truth times are the song's own absolute timeline; CREPE
/// [pitchFrames] and [recognizedWords] are both timestamped relative to
/// when recording started — this shifts them by [recordStartOffset] before
/// comparing, the same convention [alignLyrics] already uses.
///
///  - Frames below [confidenceThreshold] are excluded first.
///  - If confident frames fall inside a syllable's window, the median MIDI
///    pitch among them is the representative actual pitch — robust against
///    a single outlier frame (e.g. a stray octave error), and this is what
///    keeps normal vibrato/small movement from flipping the whole syllable
///    to SHARP/FLAT on one noisy frame. All of that window's frame
///    frequencies are preserved on the segment (see
///    [SingingSegment.frameFrequencies]) so pitch movement within the
///    syllable can still be inspected, even though the summary reduces it
///    to one representative value.
///  - Ground-truth syllables can be very short, so if no frame lands
///    exactly inside, this falls back to the nearest confident frame to
///    the window's midpoint, within [nearestFrameToleranceMs] — otherwise
///    the syllable correctly gets [PitchFeedback.noSignal] rather than a
///    guessed SHARP/FLAT. That radius is intentionally tight (default
///    80ms, a little over one CREPE hop at the 50ms hop rate this is
///    called with): ground-truth syllables often sit only 100–300ms
///    apart, so a generous fallback risks "borrowing" a neighboring
///    syllable's real pitch for a syllable the singer was actually
///    silent on, misreporting a genuine silence as IN TUNE/SHARP/FLAT.
///  - [actualWord] similarly falls back to the nearest recognized word
///    within [nearestWordToleranceMs] when none overlaps directly — a
///    ground-truth syllable is often much shorter than a Whisper word.
///  - Target vs actual is compared in cents via [analyzeFrequency]
///    (1200 * log2(actual/target)), classified against [toleranceCents].
List<SingingSegment> buildSingingSegments({
  required List<GroundTruthSyllable> groundTruth,
  required List<PitchFrame> pitchFrames,
  required Duration recordStartOffset,
  required Duration recordEndOffset,
  List<TranscribedWord> recognizedWords = const [],
  double confidenceThreshold = kDefaultPitchConfidenceThreshold,
  double toleranceCents = kDefaultPitchToleranceCents,
  int nearestFrameToleranceMs = 80,
  int nearestWordToleranceMs = 400,
}) {
  // Only the portion of the ground truth actually covered by this
  // recording — the whole RECORDING session, not the whole song.
  final inRange = groundTruth
      .where((g) =>
          g.endTime >= recordStartOffset && g.startTime <= recordEndOffset)
      .toList();

  final voiced = pitchFrames
      .where((f) => f.hasSignal && f.confidence >= confidenceThreshold)
      .toList();
  final offsetMs = recordStartOffset.inMilliseconds;

  return inRange.map((g) {
    final startMs = g.startTime.inMilliseconds;
    final endMs = g.endTime.inMilliseconds;

    final inWindow = voiced.where((f) {
      final absMs = f.timeMs + offsetMs;
      return absMs >= startMs && absMs <= endMs;
    }).toList();

    final actualWordIndex = _findOverlappingWordIndex(
      recognizedWords,
      startMs,
      endMs,
      offsetMs,
      nearestWordToleranceMs,
    );
    final actualWord =
        actualWordIndex == null ? null : recognizedWords[actualWordIndex].text;

    double? repFreq;
    double? repConfidence;
    List<double> frameFrequencies = const [];

    if (inWindow.isNotEmpty) {
      final midis = inWindow.map((f) => freqToMidi(f.frequency)).toList()
        ..sort();
      final mid = midis.length ~/ 2;
      final medianMidi = midis.length.isOdd
          ? midis[mid]
          : (midis[mid - 1] + midis[mid]) / 2;
      repFreq = midiToFreq(medianMidi);
      repConfidence =
          inWindow.map((f) => f.confidence).reduce((a, b) => a + b) /
              inWindow.length;
      frameFrequencies = inWindow.map((f) => f.frequency).toList();
    } else {
      final midpointRelativeMs = (startMs + endMs) / 2 - offsetMs;
      PitchFrame? nearest;
      var bestDist = double.infinity;
      for (final f in voiced) {
        final dist = (f.timeMs - midpointRelativeMs).abs().toDouble();
        if (dist < bestDist) {
          bestDist = dist;
          nearest = f;
        }
      }
      if (nearest != null && bestDist <= nearestFrameToleranceMs) {
        repFreq = nearest.frequency;
        repConfidence = nearest.confidence;
        frameFrequencies = [nearest.frequency];
      }
    }

    if (repFreq == null) {
      return SingingSegment(
        syllable: g.syllable,
        startTimeMs: startMs,
        endTimeMs: endMs,
        targetNote: g.noteName,
        targetFrequency: g.frequency,
        actualWord: actualWord,
        actualWordIndex: actualWordIndex,
        actualNote: null,
        actualFrequency: null,
        differenceCents: null,
        status: PitchFeedback.noSignal,
        confidence: 0,
      );
    }

    final result = analyzeFrequency(
      repFreq,
      targetFreq: g.frequency,
      confidence: repConfidence ?? 0,
      toleranceCents: toleranceCents,
    );

    return SingingSegment(
      syllable: g.syllable,
      startTimeMs: startMs,
      endTimeMs: endMs,
      targetNote: g.noteName,
      targetFrequency: g.frequency,
      actualWord: actualWord,
      actualNote: result.fullName,
      actualFrequency: result.frequency,
      differenceCents: result.cents,
      status: result.feedback,
      confidence: result.confidence,
      frameFrequencies: frameFrequencies,
    );
  }).toList();
}

/// Finds the INDEX of whichever [recognizedWords] entry overlaps
/// [startMs, endMs] the most (both compared in the same absolute-time
/// frame, via [offsetMs] — see [buildSingingSegments]). Falls back to the
/// nearest recognized word to the window's midpoint, within [toleranceMs],
/// when nothing actually overlaps — ground-truth syllables are often
/// shorter than a whole Whisper word, so a direct overlap won't always
/// exist even when the singer was clearly saying that word at the time.
///
/// Returns the index rather than the text so callers can tell one
/// occurrence of a word from another occurrence of the same word — see
/// [SingingSegment.actualWordIndex].
int? _findOverlappingWordIndex(
  List<TranscribedWord> recognizedWords,
  int startMs,
  int endMs,
  int offsetMs,
  int toleranceMs,
) {
  int? bestOverlapIndex;
  var bestOverlap = 0;

  for (var i = 0; i < recognizedWords.length; i++) {
    final w = recognizedWords[i];
    final wStart = w.startTime.inMilliseconds + offsetMs;
    final wEnd = w.endTime.inMilliseconds + offsetMs;
    final overlap = (endMs < wEnd ? endMs : wEnd) - (startMs > wStart ? startMs : wStart);
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      bestOverlapIndex = i;
    }
  }
  if (bestOverlapIndex != null) return bestOverlapIndex;

  final midpointMs = (startMs + endMs) / 2;
  int? nearestIndex;
  var bestDist = double.infinity;
  for (var i = 0; i < recognizedWords.length; i++) {
    final w = recognizedWords[i];
    final wMidMs =
        (w.startTime.inMilliseconds + w.endTime.inMilliseconds) / 2 + offsetMs;
    final dist = (wMidMs - midpointMs).abs();
    if (dist < bestDist) {
      bestDist = dist;
      nearestIndex = i;
    }
  }
  return bestDist <= toleranceMs ? nearestIndex : null;
}

/// Groups a chronological list of segments into readable "phrases" for
/// display — a new phrase starts after a natural pause ([gapMs] between
/// one segment's end and the next one's start) or once a phrase reaches
/// [maxPerPhrase] segments, whichever comes first. Whisper's own word
/// timing isn't used for these boundaries: ground-truth syllable timing is
/// already precise and reliably ordered, and introducing a second,
/// separately-aligned timing source here would risk phrase breaks that
/// don't actually line up with the syllables being grouped — this
/// deliberately stays a simple, accurate, time-based grouping instead.
List<List<SingingSegment>> groupSingingSegmentsIntoPhrases(
  List<SingingSegment> segments, {
  int maxPerPhrase = 6,
  int gapMs = 1200,
}) {
  final phrases = <List<SingingSegment>>[];
  var current = <SingingSegment>[];
  int? prevEnd;

  for (final seg in segments) {
    final naturalPause = prevEnd != null && seg.startTimeMs - prevEnd > gapMs;
    if (current.isNotEmpty &&
        (current.length >= maxPerPhrase || naturalPause)) {
      phrases.add(current);
      current = [];
    }
    current.add(seg);
    prevEnd = seg.endTimeMs;
  }
  if (current.isNotEmpty) phrases.add(current);
  return phrases;
}

/// Groups consecutive segments belonging to the same recognized-word
/// OCCURRENCE into one run — e.g. a word sung across 4 ground-truth
/// syllables becomes one group of 4, instead of that word's text appearing
/// 4 times in a row in the UI. Ground-truth syllables (and the CREPE pitch
/// frames behind them) are a much finer time grid than Whisper's
/// word-level output, so one recognized word routinely spans several
/// consecutive syllables; without this, a display that shows one syllable
/// per row reads as "word word word word" instead of lyrics, and natural
/// vibrato or a pitch slide inside one syllable would look like the singer
/// had repeated themselves.
///
/// Grouping keys on [SingingSegment.actualWordIndex] — the occurrence —
/// NOT on the word's text, so a singer who actually sings "kita, kita,"
/// still gets two separate groups even though both say the same thing.
/// Sessions saved before that index existed fall back to comparing text,
/// which is the best available signal for already-stored data.
/// Consecutive segments with no recognized word group together too, for
/// the same reason. Purely a display grouping — every segment's own data
/// (pitch, cents, status, timing, frame frequencies) is untouched and
/// still individually available inside the group.
List<List<SingingSegment>> groupSegmentsByRecognizedWord(
  List<SingingSegment> segments,
) {
  final groups = <List<SingingSegment>>[];
  var current = <SingingSegment>[];

  bool sameOccurrence(SingingSegment a, SingingSegment b) {
    if (a.actualWordIndex != null || b.actualWordIndex != null) {
      return a.actualWordIndex == b.actualWordIndex;
    }
    return a.actualWord == b.actualWord;
  }

  for (final seg in segments) {
    if (current.isNotEmpty && !sameOccurrence(current.last, seg)) {
      groups.add(current);
      current = [];
    }
    current.add(seg);
  }
  if (current.isNotEmpty) groups.add(current);
  return groups;
}

/// One lyric line's worth of the timeline: the reference line text and the
/// segments that fall inside its time window. See [groupSegmentsByLyricLine].
class LyricLineSegments {
  /// The reference lyric line, e.g. "Nasa 'yo na ang lahat, minamahal kita".
  /// Empty when segments fall outside every known line (instrumental, or a
  /// song whose lyric timing doesn't cover this part).
  final String lineText;
  final List<SingingSegment> segments;

  const LyricLineSegments({required this.lineText, required this.segments});

  int get startTimeMs => segments.first.startTimeMs;
  int get endTimeMs => segments.last.endTimeMs;
}

/// Groups segments into the LYRIC LINES they were sung over, so the
/// timeline reads like a lyric sheet — one line per section, in song
/// order — instead of arbitrary time-sliced phrases.
///
/// [lyrics] are the song's own timed lines (LRC); a line owns the window
/// from its own timestamp up to the next line's. Segments carry absolute
/// song-timeline times (same clock as the lyrics), so each one is placed by
/// its start time. Lines with no segments in them are dropped — the singer
/// never reached those — and anything before the first line is kept as one
/// untitled leading group rather than being silently discarded.
List<LyricLineSegments> groupSegmentsByLyricLine(
  List<SingingSegment> segments,
  List<LrcLine> lyrics,
) {
  if (segments.isEmpty) return const [];
  if (lyrics.isEmpty) {
    return [LyricLineSegments(lineText: '', segments: List.of(segments))];
  }

  final sortedLyrics = List<LrcLine>.of(lyrics)
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  // Index of the lyric line whose window contains [ms], or null when it
  // falls before the very first line.
  int? lineIndexFor(int ms) {
    int? found;
    for (var i = 0; i < sortedLyrics.length; i++) {
      if (sortedLyrics[i].timestamp.inMilliseconds <= ms) {
        found = i;
      } else {
        break; // sorted — no later line can start earlier
      }
    }
    return found;
  }

  final grouped = <int?, List<SingingSegment>>{};
  for (final seg in segments) {
    grouped.putIfAbsent(lineIndexFor(seg.startTimeMs), () => []).add(seg);
  }

  final keys = grouped.keys.toList()
    ..sort((a, b) {
      if (a == null) return -1; // pre-first-line group leads
      if (b == null) return 1;
      return a.compareTo(b);
    });

  return [
    for (final key in keys)
      LyricLineSegments(
        lineText: key == null ? '' : sortedLyrics[key].text,
        segments: grouped[key]!,
      ),
  ];
}
