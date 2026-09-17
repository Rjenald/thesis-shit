import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/note_utils.dart';
import 'package:final_thesis_ui/core/word_note_builder.dart';

/// A4 = 440Hz, B4 ≈ 493.88Hz — far enough apart to read as different notes.
const _a4 = 440.0;
const _b4 = 493.88;

void main() {
  group('buildPitchOnlyNotes', () {
    test('keeps detected pitch when speech recognition found nothing', () {
      final frames = [
        for (var t = 0; t <= 500; t += 50)
          PitchFrame(timeMs: t, frequency: _a4, confidence: 0.9),
      ];

      final entries = buildPitchOnlyNotes(pitchFrames: frames);

      expect(entries, hasLength(1));
      expect(entries.single.startTimeMs, 0);
      expect(entries.single.endTimeMs, 500);
      expect(entries.single.word, isEmpty,
          reason: 'no word was recognized, so none may be invented');
      expect(entries.single.syllableNotes.single, 'A4');
    });

    test('a held note is one entry, not one per pitch frame', () {
      // 20 frames of the same sustained note must not become 20 entries.
      final frames = [
        for (var t = 0; t < 20 * 50; t += 50)
          PitchFrame(timeMs: t, frequency: _a4, confidence: 0.9),
      ];

      final entries = buildPitchOnlyNotes(pitchFrames: frames);

      expect(entries, hasLength(1));
      expect(entries.single.syllableNotes, ['A4']);
    });

    test('a slide between notes is shown as movement inside one entry', () {
      final frames = [
        for (var t = 0; t <= 200; t += 50)
          PitchFrame(timeMs: t, frequency: _a4, confidence: 0.9),
        for (var t = 250; t <= 450; t += 50)
          PitchFrame(timeMs: t, frequency: _b4, confidence: 0.9),
      ];

      final entries = buildPitchOnlyNotes(pitchFrames: frames);

      expect(entries, hasLength(1));
      expect(entries.single.syllableNotes, ['A4', 'B4']);
    });

    test('a silent gap starts a new entry', () {
      final frames = [
        PitchFrame(timeMs: 0, frequency: _a4, confidence: 0.9),
        PitchFrame(timeMs: 100, frequency: _a4, confidence: 0.9),
        PitchFrame(timeMs: 200, frequency: _a4, confidence: 0.9),
        // 1.5s of silence
        PitchFrame(timeMs: 1700, frequency: _b4, confidence: 0.9),
        PitchFrame(timeMs: 1800, frequency: _b4, confidence: 0.9),
        PitchFrame(timeMs: 1900, frequency: _b4, confidence: 0.9),
      ];

      final entries = buildPitchOnlyNotes(pitchFrames: frames);

      expect(entries, hasLength(2));
      expect(entries[0].endTimeMs, 200);
      expect(entries[1].startTimeMs, 1700);
    });

    test('low-confidence frames are excluded, never shown as real notes', () {
      final frames = [
        for (var t = 0; t <= 500; t += 50)
          PitchFrame(timeMs: t, frequency: _a4, confidence: 0.01),
      ];
      expect(buildPitchOnlyNotes(pitchFrames: frames), isEmpty);
    });

    test('momentary blips are dropped rather than shown as notes', () {
      final frames = [
        PitchFrame(timeMs: 0, frequency: _a4, confidence: 0.9),
        PitchFrame(timeMs: 50, frequency: _a4, confidence: 0.9),
      ];
      // 50ms run is below the 100ms floor.
      expect(buildPitchOnlyNotes(pitchFrames: frames), isEmpty);
    });

    test('no pitch frames produce no entries', () {
      expect(buildPitchOnlyNotes(pitchFrames: const []), isEmpty);
    });
  });
}
