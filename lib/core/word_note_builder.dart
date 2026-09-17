/// Combines Whisper word-level transcription with a batch CREPE pitch pass
/// into an ordered "word + note(s)" summary for a reference-free recording —
/// see [buildWordNotes].
library;

import '../models/word_note_entry.dart';
import 'lyric_alignment_service.dart' show TranscribedWord;
import 'note_utils.dart';

/// For each recognized [word], splits it into syllables (see
/// [splitIntoSyllables]) and its Whisper time window into that many equal
/// sub-windows, then picks a representative note per syllable from the
/// CREPE frames in/near that sub-window:
///
///  - Frames below [confidenceThreshold] are treated as silence/noise and
///    excluded first.
///  - If confident frames fall inside the sub-window, the median MIDI pitch
///    among them is used — more robust than a mean against a single
///    outlier frame (e.g. a stray octave error).
///  - Whisper's per-word windows are often only tens of milliseconds wide
///    (word-level timing granularity, further divided per syllable here),
///    so it's common for the CREPE hop grid to have no sample exactly
///    inside a given sub-window. When that happens, this falls back to the
///    nearest confident frame to the sub-window's midpoint, as long as it's
///    within [nearestFrameToleranceMs] — otherwise the syllable correctly
///    gets a null note rather than a guess.
List<WordNoteEntry> buildWordNotes({
  required List<TranscribedWord> words,
  required List<PitchFrame> pitchFrames,
  double confidenceThreshold = kDefaultPitchConfidenceThreshold,
  int nearestFrameToleranceMs = 250,
}) {
  final voiced = pitchFrames
      .where((f) => f.hasSignal && f.confidence >= confidenceThreshold)
      .toList();

  return words.map((word) {
    final startMs = word.startTime.inMilliseconds;
    final endMs = word.endTime.inMilliseconds;
    final totalMs = endMs > startMs ? endMs - startMs : 0;

    final syllables = splitIntoSyllables(word.text);
    final syllableCount = syllables.isEmpty ? 1 : syllables.length;

    final syllableNotes = List<String?>.generate(syllableCount, (i) {
      final segStart = startMs + (totalMs * i / syllableCount).round();
      final segEnd = startMs + (totalMs * (i + 1) / syllableCount).round();
      return _noteForWindow(voiced, segStart, segEnd, nearestFrameToleranceMs);
    });

    return WordNoteEntry(
      word: word.text,
      syllableNotes: syllableNotes,
      startTimeMs: startMs,
      endTimeMs: endMs,
    );
  }).toList();
}

/// Groups confident CREPE frames into contiguous voiced runs and emits one
/// entry per run, carrying NO word — for a recording where the speech model
/// recognized nothing but real pitch was still detected.
///
/// Whisper failing (a quiet take, singing rather than speech, a language it
/// handles poorly) says nothing about whether CREPE found pitch: they are
/// independent analyses of the same audio. Without this, every timestamp
/// and note the pitch pass genuinely produced would be discarded just
/// because the *other* model came back empty, leaving the user an empty
/// screen instead of the analysis that did succeed. No text is attached
/// rather than guessing at words that were never recognized.
///
/// A run ends after [gapMs] of silence; runs shorter than [minRunMs] are
/// dropped as blips rather than shown as notes.
List<WordNoteEntry> buildPitchOnlyNotes({
  required List<PitchFrame> pitchFrames,
  double confidenceThreshold = kDefaultPitchConfidenceThreshold,
  int gapMs = 300,
  int minRunMs = 100,
  int maxNotesPerRun = 4,
}) {
  final voiced = pitchFrames
      .where((f) => f.hasSignal && f.confidence >= confidenceThreshold)
      .toList()
    ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
  if (voiced.isEmpty) return const [];

  final runs = <List<PitchFrame>>[];
  var current = <PitchFrame>[voiced.first];
  for (var i = 1; i < voiced.length; i++) {
    if (voiced[i].timeMs - voiced[i - 1].timeMs > gapMs) {
      runs.add(current);
      current = [];
    }
    current.add(voiced[i]);
  }
  runs.add(current);

  final entries = <WordNoteEntry>[];
  for (final run in runs) {
    final startMs = run.first.timeMs;
    final endMs = run.last.timeMs;
    if (endMs - startMs < minRunMs) continue;

    // Collapse consecutive frames that landed on the same note, so a held
    // note reads as one note and a slide reads as the notes it moved
    // through — never one entry per raw frame.
    final notes = <String>[];
    for (final frame in run) {
      final note = _midiToNoteWithOctave(freqToMidi(frame.frequency).round());
      if (notes.isEmpty || notes.last != note) notes.add(note);
    }

    entries.add(WordNoteEntry(
      word: '',
      syllableNotes: notes.take(maxNotesPerRun).toList(),
      startTimeMs: startMs,
      endTimeMs: endMs,
    ));
  }
  return entries;
}

String? _noteForWindow(
  List<PitchFrame> voiced,
  int startMs,
  int endMs,
  int toleranceMs,
) {
  final inWindow = voiced
      .where((f) => f.timeMs >= startMs && f.timeMs <= endMs)
      .map((f) => freqToMidi(f.frequency))
      .toList();
  if (inWindow.isNotEmpty) {
    return _midiToNoteWithOctave(_median(inWindow));
  }

  // No frame landed exactly inside this (often very narrow) window — fall
  // back to the closest confident frame to its midpoint, within tolerance.
  final midpoint = (startMs + endMs) / 2;
  PitchFrame? nearest;
  var bestDist = double.infinity;
  for (final f in voiced) {
    final dist = (f.timeMs - midpoint).abs().toDouble();
    if (dist < bestDist) {
      bestDist = dist;
      nearest = f;
    }
  }
  if (nearest != null && bestDist <= toleranceMs) {
    return _midiToNoteWithOctave(freqToMidi(nearest.frequency).round());
  }
  return null;
}

int _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
  return median.round();
}

String _midiToNoteWithOctave(int midi) =>
    '${midiToNoteName(midi)}${midiToOctave(midi)}';

// ── Syllable splitting ────────────────────────────────────────────────────
// No syllable-level output exists from Whisper (word-level is its finest
// granularity), so this is a simple, language-agnostic heuristic: each run
// of vowels is one syllable nucleus, and a consonant run between two nuclei
// splits roughly in half (extra consonant favors the next syllable's onset,
// e.g. "happy" -> "hap"+"py", "extra" -> "ex"+"tra") — the same convention
// common hyphenation heuristics use. It's an approximation, not a
// dictionary-backed syllabifier, but is good enough to give each syllable
// its own timing sub-window for pitch detection.
final _vowelGroupPattern = RegExp(r'[aeiouyAEIOUY]+');

List<String> splitIntoSyllables(String word) {
  final clean = word.trim();
  if (clean.isEmpty) return const [];

  final vowelGroups = _vowelGroupPattern.allMatches(clean).toList();
  if (vowelGroups.length <= 1) return [clean];

  final syllables = <String>[];
  var syllableStart = 0;
  for (var g = 0; g < vowelGroups.length - 1; g++) {
    final thisGroupEnd = vowelGroups[g].end;
    final nextGroupStart = vowelGroups[g + 1].start;
    final consonants = nextGroupStart - thisGroupEnd;
    final splitAt = thisGroupEnd + (consonants ~/ 2);
    syllables.add(clean.substring(syllableStart, splitAt));
    syllableStart = splitAt;
  }
  syllables.add(clean.substring(syllableStart));
  return syllables;
}
