/// Combines Whisper word-level transcription with a batch CREPE pitch pass
/// into an ordered "word + note" summary for a reference-free recording —
/// see [buildWordNotes].
library;

import '../models/word_note_entry.dart';
import 'lyric_alignment_service.dart' show TranscribedWord;
import 'note_utils.dart';

/// For each recognized [word], averages the CREPE pitch frames that fall
/// within its [startTime, endTime] window (confidence-weighted, in MIDI
/// space so octave jumps don't skew a plain Hz average) into a single note
/// name. Frames below [confidenceThreshold] are treated as silence/noise
/// and excluded. A word with no confident frames in its window gets a null
/// note rather than being dropped, so the transcript stays complete.
List<WordNoteEntry> buildWordNotes({
  required List<TranscribedWord> words,
  required List<PitchFrame> pitchFrames,
  double confidenceThreshold = 0.5,
}) {
  final voiced = pitchFrames
      .where((f) => f.hasSignal && f.confidence >= confidenceThreshold)
      .toList();

  return words.map((word) {
    final startMs = word.startTime.inMilliseconds;
    final endMs = word.endTime.inMilliseconds;

    final inWindow = voiced.where(
      (f) => f.timeMs >= startMs && f.timeMs <= endMs,
    );

    double weightedMidi = 0;
    double weightSum = 0;
    for (final frame in inWindow) {
      final midi = freqToMidi(frame.frequency);
      weightedMidi += midi * frame.confidence;
      weightSum += frame.confidence;
    }

    final note = weightSum > 0
        ? _midiToNoteWithOctave((weightedMidi / weightSum).round())
        : null;

    return WordNoteEntry(
      word: word.text,
      note: note,
      startTimeMs: startMs,
      endTimeMs: endMs,
    );
  }).toList();
}

String _midiToNoteWithOctave(int midi) =>
    '${midiToNoteName(midi)}${midiToOctave(midi)}';
