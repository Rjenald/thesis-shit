import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/piano_audio.dart';
import 'package:final_thesis_ui/widgets/playable_piano.dart';

/// The keyboard in the drills, which used to be decorative.
///
/// Both drill screens drew it with a `CustomPaint` and no gesture
/// handling, so a key lit up when the microphone heard that pitch and
/// pressing one did nothing at all.
///
/// The part most worth pinning is the hit test. Black keys are drawn
/// *over* the white ones, so a hit test that disagreed with the painter
/// by a few pixels would play the wrong note around every accidental —
/// which a player reads as the keyboard being out of tune, not
/// mis-aimed. The geometry constants are shared between the two for
/// exactly that reason, and these tests check they stay in step.
void main() {
  const size = Size(320, 112);
  final whiteW = size.width / PianoPainter.whiteKeys.length;

  group('hit test', () {
    test('every white key is hit at the bottom of its own column', () {
      for (var i = 0; i < PianoPainter.whiteKeys.length; i++) {
        final x = i * whiteW + whiteW / 2;
        // Below the black keys, so only the white one can be there.
        final midi = PlayablePiano.midiAt(Offset(x, size.height - 4), size);
        expect(midi, PianoPainter.whiteKeys[i],
            reason: 'white key $i at x=$x');
      }
    });

    test('every black key is hit at its own centre', () {
      PianoPainter.blackKeyCenters.forEach((midi, frac) {
        final x = frac * whiteW;
        final y = size.height * PianoPainter.blackKeyHeightFactor / 2;
        expect(PlayablePiano.midiAt(Offset(x, y), size), midi,
            reason: 'black key $midi at x=$x');
      });
    });

    test('a black key wins where it overlaps a white one', () {
      // The whole point: in the top 60% of the keyboard, the black key is
      // drawn on top, so that is what a finger is aiming at.
      PianoPainter.blackKeyCenters.forEach((midi, frac) {
        final x = frac * whiteW;
        final high = Offset(x, 4);
        final low = Offset(x, size.height - 4);
        expect(PlayablePiano.midiAt(high, size), midi,
            reason: 'high up, the black key should win');
        expect(PlayablePiano.midiAt(low, size), isNot(midi),
            reason: 'below it, the white key underneath should win');
      });
    });

    test('below a black key you get the white key under it', () {
      final x = 1.0 * whiteW; // C#4's centre sits on the C4/D4 boundary
      final below = PlayablePiano.midiAt(Offset(x, size.height - 4), size);
      expect(below, anyOf(60, 62));
    });

    test('taps outside the keyboard hit nothing', () {
      expect(PlayablePiano.midiAt(const Offset(-5, 50), size), isNull);
      expect(PlayablePiano.midiAt(Offset(size.width + 5, 50), size), isNull);
      expect(PlayablePiano.midiAt(const Offset(10, -2), size), isNull);
      expect(
          PlayablePiano.midiAt(Offset(10, size.height + 2), size), isNull);
    });

    test('a zero-sized keyboard does not divide by zero', () {
      expect(PlayablePiano.midiAt(Offset.zero, Size.zero), isNull);
      expect(PlayablePiano.midiAt(const Offset(1, 1), const Size(0, 112)),
          isNull);
    });

    test('the far right edge still resolves to the last key', () {
      final midi =
          PlayablePiano.midiAt(Offset(size.width - 0.5, size.height - 4), size);
      expect(midi, PianoPainter.whiteKeys.last);
    });

    test('it works at any width, because the layout is proportional', () {
      for (final w in [120.0, 200.0, 320.0, 480.0, 900.0]) {
        final s = Size(w, 112);
        final step = w / PianoPainter.whiteKeys.length;
        for (var i = 0; i < PianoPainter.whiteKeys.length; i++) {
          expect(
              PlayablePiano.midiAt(
                  Offset(i * step + step / 2, 108), s),
              PianoPainter.whiteKeys[i],
              reason: 'width $w, key $i');
        }
      }
    });
  });

  group('key data', () {
    test('every key in the octave is reachable by the hit test', () {
      final reachable = <int>{};
      for (double x = 0; x < size.width; x += 0.5) {
        for (final y in [2.0, size.height * 0.3, size.height - 2]) {
          final m = PlayablePiano.midiAt(Offset(x, y), size);
          if (m != null) reachable.add(m);
        }
      }
      final drawn = {
        ...PianoPainter.whiteKeys,
        ...PianoPainter.blackKeyCenters.keys,
      };
      expect(reachable, drawn,
          reason: 'a key that is drawn but cannot be pressed is the bug '
              'this widget exists to fix');
    });

    test('pianoOctaveKeys and the painter agree on which keys exist', () {
      final fromData = pianoOctaveKeys.map((k) => k.midi).toSet();
      final fromPainter = {
        ...PianoPainter.whiteKeys,
        ...PianoPainter.blackKeyCenters.keys,
      };
      expect(fromData, fromPainter);
    });

    test('black flags in the data match the painter', () {
      for (final k in pianoOctaveKeys) {
        expect(PianoPainter.blackKeyCenters.containsKey(k.midi), k.isBlack,
            reason: '${k.name} isBlack=${k.isBlack}');
      }
    });

    test('frequencies round-trip to the MIDI numbers they claim', () {
      for (final k in pianoOctaveKeys) {
        expect((frequencyForMidi(k.midi) - k.freq).abs(), lessThan(0.6),
            reason: '${k.name}: ${k.freq} Hz vs MIDI ${k.midi}');
      }
    });

    test('solfège labels line up with the white keys', () {
      expect(PianoPainter.solfegeLabels.length,
          PianoPainter.whiteKeys.length);
      expect(PianoPainter.solfegeLabels.first, 'Do');
      expect(PianoPainter.solfegeLabels.last, 'Do');
    });

    test('any octave folds into the drawn one', () {
      expect(PianoPainter.normalise(48), 60);
      expect(PianoPainter.normalise(84), 60);
      expect(PianoPainter.normalise(73), 61);
      expect(PianoPainter.normalise(null), isNull);
    });
  });

  group('synthesis', () {
    /// Reads the 16-bit mono samples back out of a WAV buffer.
    List<int> samples(Uint8List wav) {
      final bd = ByteData.sublistView(wav);
      return [
        for (var i = 44; i + 1 < wav.length; i += 2)
          bd.getInt16(i, Endian.little)
      ];
    }

    test('it produces a valid 44.1kHz mono 16-bit WAV', () {
      final wav = makePianoWav(440.0, ms: 200);
      final bd = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(bd.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(bd.getUint32(24, Endian.little), 44100);
      expect(bd.getUint16(34, Endian.little), 16, reason: '16-bit');
      expect(bd.getUint32(4, Endian.little), wav.length - 8,
          reason: 'RIFF size must match the buffer');
      expect(bd.getUint32(40, Endian.little), wav.length - 44,
          reason: 'data size must match the payload');
    });

    test('the length matches the duration asked for', () {
      for (final ms in [100, 500, 1200]) {
        final wav = makePianoWav(440.0, ms: ms);
        expect(samples(wav).length, (44100 * ms / 1000).round(),
            reason: '$ms ms');
      }
    });

    test('it decays, which is what makes it a piano and not an organ', () {
      // The version this replaced had a flat envelope with a release at
      // the end, and the ear reads that as a blown or bowed instrument.
      final s = samples(makePianoWav(440.0, ms: 1200));
      double peakIn(double from, double to) {
        final a = (s.length * from).round(), b = (s.length * to).round();
        return s.sublist(a, b).map((v) => v.abs()).reduce(max).toDouble();
      }

      final early = peakIn(0.02, 0.10);
      final middle = peakIn(0.40, 0.50);
      final late = peakIn(0.80, 0.90);
      expect(middle, lessThan(early * 0.75),
          reason: 'should be well down by the middle');
      expect(late, lessThan(middle * 0.75),
          reason: 'and quieter again by the end');
    });

    test('it starts at silence and ends at silence', () {
      final s = samples(makePianoWav(440.0, ms: 800));
      expect(s.first.abs(), lessThan(400), reason: 'attack from zero');
      expect(s.last.abs(), lessThan(400),
          reason: 'a key that stops abruptly clicks');
    });

    test('nothing clips, at any pitch in the octave', () {
      for (final k in pianoOctaveKeys) {
        final s = samples(makePianoWav(k.freq, ms: 300));
        final peak = s.map((v) => v.abs()).reduce(max);
        expect(peak, lessThan(32767),
            reason: '${k.name} clipped at $peak');
        expect(peak, greaterThan(8000),
            reason: '${k.name} is too quiet to hear ($peak)');
      }
    });

    test('a higher note decays faster, as a real string does', () {
      double tailRatio(double hz) {
        final s = samples(makePianoWav(hz, ms: 1200));
        double peakIn(double from, double to) {
          final a = (s.length * from).round(), b = (s.length * to).round();
          return s.sublist(a, b).map((v) => v.abs()).reduce(max).toDouble();
        }

        return peakIn(0.45, 0.55) / max(peakIn(0.02, 0.10), 1);
      }

      expect(tailRatio(523.25), lessThan(tailRatio(261.63)),
          reason: 'C5 should die away sooner than C4');
    });

    test('the fundamental is the pitch asked for', () {
      // Zero crossings over a window early in the note, where the
      // fundamental dominates, should match the frequency.
      for (final hz in [261.63, 440.0, 523.25]) {
        final s = samples(makePianoWav(hz, ms: 400));
        final from = (44100 * 0.02).round();
        final to = (44100 * 0.12).round();
        var crossings = 0;
        for (var i = from + 1; i < to; i++) {
          if ((s[i - 1] < 0) != (s[i] < 0)) crossings++;
        }
        final measured = crossings / 2 / 0.10;
        expect((measured - hz).abs() / hz, lessThan(0.08),
            reason: 'asked $hz Hz, measured ${measured.toStringAsFixed(1)}');
      }
    });
  });

  group('widget', () {
    testWidgets('it renders and takes a press without throwing',
        (tester) async {
      int? played;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayablePiano(onNotePressed: (m) => played = m),
        ),
      ));
      expect(find.byType(PlayablePiano), findsOneWidget);

      await tester.tap(find.byType(PlayablePiano));
      await tester.pump();
      // No audio engine in a test binding, so nothing sounds and the
      // callback does not fire. What matters is that the gesture path
      // does not throw.
      expect(tester.takeException(), isNull);
      expect(played, isNull);
    });

    testWidgets('a disabled keyboard still draws', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PlayablePiano(enabled: false)),
      ));
      await tester.tap(find.byType(PlayablePiano));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('it survives being disposed straight away', (tester) async {
      // The pool loads off the first frame, so a screen left immediately
      // tears down mid-load. That used to be a real source of "setState
      // after dispose".
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PlayablePiano()),
      ));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SizedBox()),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
