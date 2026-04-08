/// Converts raw frequencies (Hz) into musical notes, solfège syllables,
/// and cents-deviation feedback.
library;

import 'dart:math';

// ── Note names (chromatic scale starting at C) ───────────────────────────────
const List<String> kNoteNames = [
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

// ── Solfège syllables for the C-major diatonic scale ─────────────────────────
// Only the 7 natural notes have solfège names in Do-Re-Mi training.
// Sharps/flats are considered "between notes" for our purposes.
const Map<int, String> kDiatonicSolfege = {
  0: 'Do', // C
  2: 'Re', // D
  4: 'Mi', // E
  5: 'Fa', // F
  7: 'Sol', // G
  9: 'La', // A
  11: 'Ti', // B  (some traditions use "Si")
};

// ── Reference frequencies for C4 (middle C) through B4 ───────────────────────
// Generated from A4 = 440 Hz: freq = 440 * 2^((midi - 69) / 12)
const Map<String, double> kNoteFrequencies = {
  'C4': 261.63,
  'D4': 293.66,
  'E4': 329.63,
  'F4': 349.23,
  'G4': 392.00,
  'A4': 440.00,
  'B4': 493.88,
  'C5': 523.25,
};

// ── Do-Re-Mi lesson sequence ──────────────────────────────────────────────────
const List<LessonNote> kDoReMiSequence = [
  LessonNote(noteName: 'C4', solfege: 'Do', frequency: 261.63),
  LessonNote(noteName: 'D4', solfege: 'Re', frequency: 293.66),
  LessonNote(noteName: 'E4', solfege: 'Mi', frequency: 329.63),
  LessonNote(noteName: 'F4', solfege: 'Fa', frequency: 349.23),
  LessonNote(noteName: 'G4', solfege: 'Sol', frequency: 392.00),
  LessonNote(noteName: 'A4', solfege: 'La', frequency: 440.00),
  LessonNote(noteName: 'B4', solfege: 'Ti', frequency: 493.88),
  LessonNote(noteName: 'C5', solfege: 'Do', frequency: 523.25),
];

class LessonNote {
  final String noteName;
  final String solfege;
  final double frequency;
  const LessonNote({
    required this.noteName,
    required this.solfege,
    required this.frequency,
  });
}

// ── Core conversion functions ─────────────────────────────────────────────────

/// Convert a frequency in Hz to a fractional MIDI note number.
/// A4 (440 Hz) = MIDI 69. Each semitone = 1 MIDI step.
///
/// Formula: midi = 69 + 12 × log₂(freq / 440)
double freqToMidi(double freq) {
  if (freq <= 0) return 0.0;
  return 69.0 + 12.0 * log(freq / 440.0) / ln2;
}

/// Round a fractional MIDI number to the nearest integer (nearest semitone).
int midiToNearestNote(double midi) => midi.round();

/// Return the chromatic note name (e.g. "A", "C#") for a MIDI note number.
String midiToNoteName(int midi) => kNoteNames[midi % 12];

/// Return the octave number for a MIDI note (C4 = MIDI 60, octave 4).
int midiToOctave(int midi) => (midi ~/ 12) - 1;

/// Return the solfège syllable for a note's chromatic index (0–11), or null
/// if it is a chromatic note not in the C-major scale.
String? noteIndexToSolfege(int chromatic) => kDiatonicSolfege[chromatic];

/// Cents deviation of `freq` from the nearest equal-tempered semitone.
/// Positive = sharp (too high), negative = flat (too low).
/// Range: −50 to +50 cents.
///
/// Formula: cents = (midi − round(midi)) × 100
double centsFromNearest(double freq) {
  final midi = freqToMidi(freq);
  return (midi - midi.round()) * 100.0;
}

/// Cents deviation of `detectedFreq` from a specific `targetFreq`.
/// Used in lesson mode to compare against a known target note.
double centsFromTarget(double detectedFreq, double targetFreq) {
  if (detectedFreq <= 0 || targetFreq <= 0) return 0.0;
  return 1200.0 * log(detectedFreq / targetFreq) / ln2;
}

// ── Feedback classification ───────────────────────────────────────────────────

enum PitchFeedback { correct, tooHigh, tooLow, noSignal }

/// Classify the singing feedback given a cents deviation.
///
/// [toleranceCents] defines the "in-tune" window.
/// 25 cents = a quarter semitone — a reasonable tolerance for beginners.
/// 15 cents = stricter, suitable for more advanced practice.
PitchFeedback classifyPitch(double cents, {double toleranceCents = 25.0}) {
  if (cents.abs() <= toleranceCents) return PitchFeedback.correct;
  if (cents > 0) return PitchFeedback.tooHigh;
  return PitchFeedback.tooLow;
}

/// Full analysis of a detected frequency against an optional target.
NoteResult analyzeFrequency(double freq, {double? targetFreq}) {
  final midi = freqToMidi(freq);
  final nearestMidi = midiToNearestNote(midi);
  final noteIndex = nearestMidi % 12;
  final noteName = midiToNoteName(nearestMidi);
  final octave = midiToOctave(nearestMidi);
  final solfege = noteIndexToSolfege(noteIndex);
  final cents = targetFreq != null
      ? centsFromTarget(freq, targetFreq)
      : centsFromNearest(freq);
  final feedback = classifyPitch(cents);

  return NoteResult(
    frequency: freq,
    midiNote: nearestMidi,
    noteName: noteName,
    octave: octave,
    solfege: solfege,
    cents: cents,
    feedback: feedback,
  );
}

// ── Data class ────────────────────────────────────────────────────────────────

class NoteResult {
  final double frequency;
  final int midiNote;
  final String noteName;
  final int octave;
  final String? solfege; // null for chromatic (non-diatonic) notes
  final double cents;
  final PitchFeedback feedback;

  const NoteResult({
    required this.frequency,
    required this.midiNote,
    required this.noteName,
    required this.octave,
    required this.solfege,
    required this.cents,
    required this.feedback,
  });

  /// Human-readable note with octave, e.g. "A4" or "C#3".
  String get fullName => '$noteName$octave';

  /// Display name: solfège if available, else note name.
  String get displayName => solfege ?? noteName;

  @override
  String toString() =>
      'NoteResult($fullName, ${frequency.toStringAsFixed(1)} Hz, '
      '${cents.toStringAsFixed(1)} cents, $feedback)';
}
