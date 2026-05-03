/// Converts raw frequencies (Hz) into musical notes, solfège syllables,
/// and cents-deviation feedback.
///
/// Updated for Huni CREPE integration:
///  • Added NoteResult.fromFrequency() static factory
///  • Added NoteResult.silent() factory for no-signal states
///  • Added hzToNoteName() top-level helper
///  • All existing functions unchanged — fully backward compatible
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
const Map<int, String> kDiatonicSolfege = {
  0: 'Do',  // C
  2: 'Re',  // D
  4: 'Mi',  // E
  5: 'Fa',  // F
  7: 'Sol', // G
  9: 'La',  // A
  11: 'Ti', // B
};

// ── Reference frequencies ─────────────────────────────────────────────────────
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
/// A4 (440 Hz) = MIDI 69.
double freqToMidi(double freq) {
  if (freq <= 0) return 0.0;
  return 69.0 + 12.0 * log(freq / 440.0) / ln2;
}

/// Round a fractional MIDI number to the nearest integer.
int midiToNearestNote(double midi) => midi.round();

/// Return the chromatic note name (e.g. "A", "C#") for a MIDI note number.
String midiToNoteName(int midi) => kNoteNames[midi % 12];

/// Return the octave number for a MIDI note.
int midiToOctave(int midi) => (midi ~/ 12) - 1;

/// Return the solfège syllable for a chromatic index (0–11), or null.
String? noteIndexToSolfege(int chromatic) => kDiatonicSolfege[chromatic];

/// Cents deviation of freq from the nearest equal-tempered semitone.
/// Positive = sharp, negative = flat. Range: −50 to +50.
double centsFromNearest(double freq) {
  final midi = freqToMidi(freq);
  return (midi - midi.round()) * 100.0;
}

/// Cents deviation of detectedFreq from a specific targetFreq.
double centsFromTarget(double detectedFreq, double targetFreq) {
  if (detectedFreq <= 0 || targetFreq <= 0) return 0.0;
  return 1200.0 * log(detectedFreq / targetFreq) / ln2;
}

/// Convert Hz directly to a note name string (e.g. 440.0 → "A4").
/// Used by CrepeService and AudioService for quick display.
String hzToNoteName(double hz) {
  if (hz <= 0) return '';
  final midi      = freqToMidi(hz);
  final nearestMidi = midiToNearestNote(midi);
  final noteName  = midiToNoteName(nearestMidi);
  final octave    = midiToOctave(nearestMidi);
  return '$noteName$octave';
}

// ── Feedback classification ───────────────────────────────────────────────────

enum PitchFeedback { correct, tooHigh, tooLow, noSignal }

/// Classify pitch feedback given a cents deviation.
///
/// Tolerance guide:
///  • 25 cents (default) — quarter-semitone, beginner-friendly
///  • 15 cents           — strict, advanced/performance mode
///  • 35 cents           — lenient, young/beginner students
PitchFeedback classifyPitch(double cents, {double toleranceCents = 25.0}) {
  if (cents.abs() <= toleranceCents) return PitchFeedback.correct;
  if (cents > 0) return PitchFeedback.tooHigh;
  return PitchFeedback.tooLow;
}

/// Full analysis of a detected frequency against an optional target.
///
/// [confidence] is the CREPE model confidence (0.0 – 1.0).
/// Pass 1.0 when using local YIN (no confidence available).
NoteResult analyzeFrequency(
  double freq, {
  double? targetFreq,
  double confidence = 1.0,
  double toleranceCents = 25.0,   // ← new: configurable tolerance
}) {
  final midi        = freqToMidi(freq);
  final nearestMidi = midiToNearestNote(midi);
  final noteIndex   = nearestMidi % 12;
  final noteName    = midiToNoteName(nearestMidi);
  final octave      = midiToOctave(nearestMidi);
  final solfege     = noteIndexToSolfege(noteIndex);
  final cents       = targetFreq != null
      ? centsFromTarget(freq, targetFreq)
      : centsFromNearest(freq);
  final feedback    = classifyPitch(cents, toleranceCents: toleranceCents);

  return NoteResult(
    frequency:  freq,
    midiNote:   nearestMidi,
    noteName:   noteName,
    octave:     octave,
    solfege:    solfege,
    cents:      cents,
    feedback:   feedback,
    confidence: confidence.clamp(0.0, 1.0),
  );
}

// ── Data class ────────────────────────────────────────────────────────────────

class NoteResult {
  final double frequency;
  final int midiNote;
  final String noteName;
  final int octave;
  final String? solfege;
  final double cents;
  final PitchFeedback feedback;

  /// CREPE model confidence: 0.0 (noise) → 1.0 (crystal-clear pitch).
  final double confidence;

  const NoteResult({
    required this.frequency,
    required this.midiNote,
    required this.noteName,
    required this.octave,
    required this.solfege,
    required this.cents,
    required this.feedback,
    this.confidence = 1.0,
  });

  // ── Static factories ──────────────────────────────────────────────────────

  /// Create a NoteResult directly from a frequency in Hz.
  /// Used by CrepeService and AudioService.
  ///
  /// Example:
  ///   final result = NoteResult.fromFrequency(440.0, confidence: 0.87);
  ///   print(result.fullName);    // "A4"
  ///   print(result.cents);       // ~0.0 (perfect A4)
  ///   print(result.feedback);    // PitchFeedback.correct
  static NoteResult fromFrequency(
    double freq, {
    double confidence = 1.0,
    double? targetFreq,
    double toleranceCents = 25.0,
  }) {
    return analyzeFrequency(
      freq,
      targetFreq:     targetFreq,
      confidence:     confidence,
      toleranceCents: toleranceCents,
    );
  }

  /// Create a silent / no-signal NoteResult.
  /// Used when CREPE confidence is too low or mic detects silence.
  ///
  /// Example:
  ///   _resultController.add(NoteResult.silent());
  static NoteResult silent() {
    return const NoteResult(
      frequency:  0,
      midiNote:   0,
      noteName:   '',
      octave:     0,
      solfege:    null,
      cents:      0,
      feedback:   PitchFeedback.noSignal,
      confidence: 0,
    );
  }

  // ── Computed properties ───────────────────────────────────────────────────

  /// Human-readable note with octave, e.g. "A4" or "C#3".
  String get fullName => frequency > 0 ? '$noteName$octave' : '';

  /// Display name: solfège if available, else note name.
  String get displayName => solfege ?? noteName;

  /// Voice clarity as percentage (0–100), derived from CREPE confidence.
  int get clarityPercent => (confidence * 100).round();

  /// True if this result represents actual detected pitch (not silence).
  bool get hasSignal => frequency > 0 && feedback != PitchFeedback.noSignal;

  /// True if pitch is within tolerance (in tune).
  bool get isInTune => feedback == PitchFeedback.correct;

  /// True if singing too high (sharp).
  bool get isSharp => feedback == PitchFeedback.tooHigh;

  /// True if singing too low (flat).
  bool get isFlat => feedback == PitchFeedback.tooLow;

  @override
  String toString() =>
      'NoteResult($fullName, ${frequency.toStringAsFixed(1)} Hz, '
      '${cents.toStringAsFixed(1)} ¢, $clarityPercent% clarity, $feedback)';
}