import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/lyric_alignment_service.dart'
    show normalizeWavForSpeech;

/// Builds a canonical 16-bit mono 16kHz WAV around [samples].
Uint8List _wav(List<int> samples) {
  const sampleRate = 16000, channels = 1, bitsPerSample = 16;
  final dataLength = samples.length * 2;
  final buf = ByteData(44 + dataLength);

  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      buf.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  buf.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, channels, Endian.little);
  buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * channels * bitsPerSample ~/ 8, Endian.little);
  buf.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  buf.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  buf.setUint32(40, dataLength, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    buf.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return buf.buffer.asUint8List();
}

List<int> _samplesOf(Uint8List wav) {
  final bd = ByteData.sublistView(wav);
  return [
    for (var i = 44; i + 1 < wav.length; i += 2) bd.getInt16(i, Endian.little),
  ];
}

int _peakOf(Uint8List wav) =>
    _samplesOf(wav).map((s) => s.abs()).reduce((a, b) => a > b ? a : b);

void main() {
  group('normalizeWavForSpeech', () {
    test('brings a quiet recording up to an audible level', () {
      // ~-42 dBFS — real pitch is still recoverable by CREPE here, but
      // Whisper hears effectively nothing, which is the bug this fixes.
      final quiet = _wav([120, -250, 90, -40, 260, -110]);
      expect(_peakOf(quiet), 260);

      final out = normalizeWavForSpeech(quiet);

      // The gain cap binds at this extreme (20× of 260), which still lands
      // around -16 dBFS — a normal speech level — without blowing the noise
      // floor up to full scale.
      expect(_peakOf(out), 5200);
      expect(out.length, quiet.length, reason: 'no samples added or lost');
    });

    test('a moderately quiet recording is taken to near full scale', () {
      // -20 dBFS: the realistic case, where the cap does not bind.
      final out = normalizeWavForSpeech(_wav([3000, -2500, 1800]));
      expect(_peakOf(out), greaterThan(28000));
      expect(_peakOf(out), lessThanOrEqualTo(32767));
    });

    test('preserves waveform shape and sign when amplifying', () {
      final out = normalizeWavForSpeech(_wav([100, -200, 50, -100]));
      final samples = _samplesOf(out);

      expect(samples[1].isNegative, isTrue);
      expect(samples[3].isNegative, isTrue);
      expect(samples[0].isNegative, isFalse);
      // -200 was twice the magnitude of 100, and must stay that way.
      expect(samples[1].abs() / samples[0].abs(), closeTo(2.0, 0.01));
      expect(samples[2].abs() / samples[0].abs(), closeTo(0.5, 0.01));
    });

    test('leaves an already-loud recording untouched', () {
      final loud = _wav([32000, -31000, 30500, -32700]);
      expect(normalizeWavForSpeech(loud), equals(loud));
    });

    test('leaves a silent recording untouched rather than amplifying hiss', () {
      final silent = _wav([0, 0, 0, 0]);
      expect(normalizeWavForSpeech(silent), equals(silent));

      // Noise floor only — amplifying this would just make loud hiss, which
      // a speech model is more likely to hallucinate words out of.
      final noiseFloor = _wav([3, -5, 2, -1]);
      expect(normalizeWavForSpeech(noiseFloor), equals(noiseFloor));
    });

    test('never clips past int16 range', () {
      final out = normalizeWavForSpeech(_wav([1000, -1000, 999, -998]));
      for (final s in _samplesOf(out)) {
        expect(s, inInclusiveRange(-32768, 32767));
      }
    });

    test('returns non-WAV input unchanged instead of corrupting it', () {
      final notAWav = Uint8List.fromList(List.filled(100, 7));
      expect(normalizeWavForSpeech(notAWav), equals(notAWav));
    });

    test('keeps the WAV header intact', () {
      final quiet = _wav([120, -250, 90, -40]);
      final out = normalizeWavForSpeech(quiet);
      expect(out.sublist(0, 44), equals(quiet.sublist(0, 44)));
    });
  });
}
