/// Shared piano audio utilities.
/// Used by PianoModePage, SolfegeActivityPage, and any other widget
/// that needs piano sound synthesis without external assets.
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

// ── WAV synthesis ─────────────────────────────────────────────────────────────

/// Generates a piano-like WAV buffer for [hz] at the given duration [ms].
/// Pure Dart — no asset files required.
Uint8List makePianoWav(double hz, {int ms = 700}) {
  const sr = 44100;
  final n = (sr * ms / 1000).round();
  final buf = ByteData(44 + n * 2);

  void w(int o, List<int> c) {
    for (int i = 0; i < c.length; i++) {
      buf.setUint8(o + i, c[i]);
    }
  }

  w(0, [82, 73, 70, 70]); // RIFF
  buf.setUint32(4, 36 + n * 2, Endian.little);
  w(8, [87, 65, 86, 69]); // WAVE
  w(12, [102, 109, 116, 32]); // fmt
  buf.setUint32(16, 16, Endian.little);
  buf.setUint16(20, 1, Endian.little); // PCM
  buf.setUint16(22, 1, Endian.little); // mono
  buf.setUint32(24, sr, Endian.little);
  buf.setUint32(28, sr * 2, Endian.little);
  buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little);
  w(36, [100, 97, 116, 97]); // data
  buf.setUint32(40, n * 2, Endian.little);

  final atk = (sr * 0.02).round();
  final rel = (sr * 0.15).round();
  for (int i = 0; i < n; i++) {
    double env = 1.0;
    if (i < atk) {
      env = i / atk;
    } else if (i > n - rel) {
      env = (n - i) / rel;
    }
    // Piano timbre: fundamental + 2nd + 3rd harmonic
    final t = i / sr;
    final v = sin(2 * pi * hz * t) * 0.55 +
        sin(4 * pi * hz * t) * 0.25 +
        sin(6 * pi * hz * t) * 0.10;
    final s = (env * v * 32767 * 0.75).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, s, Endian.little);
  }
  return buf.buffer.asUint8List();
}

// ── just_audio source ─────────────────────────────────────────────────────────

/// Feeds an in-memory WAV buffer to just_audio.
// ignore: experimental_member_use
class PianoWavSource extends StreamAudioSource {
  final Uint8List _bytes;
  PianoWavSource(this._bytes) : super(tag: 'piano');

  @override
  // ignore: experimental_member_use
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    // ignore: experimental_member_use
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

// ── Piano key data ────────────────────────────────────────────────────────────

/// One piano key: its name, frequency, solfège syllable,
/// note letter, and whether it's a black key.
class PianoKey {
  final String name;
  final double freq;
  final String solfege;
  final String note;
  final bool isBlack;

  const PianoKey({
    required this.name,
    required this.freq,
    required this.solfege,
    required this.note,
    this.isBlack = false,
  });
}

/// One octave C4→C5 with correct solfège labels (movable Do).
const List<PianoKey> pianoOctaveKeys = [
  PianoKey(name: 'C4',  freq: 261.63, solfege: 'Do',  note: 'C'),
  PianoKey(name: 'C#4', freq: 277.18, solfege: 'Di',  note: 'C#', isBlack: true),
  PianoKey(name: 'D4',  freq: 293.66, solfege: 'Re',  note: 'D'),
  PianoKey(name: 'D#4', freq: 311.13, solfege: 'Ri',  note: 'D#', isBlack: true),
  PianoKey(name: 'E4',  freq: 329.63, solfege: 'Mi',  note: 'E'),
  PianoKey(name: 'F4',  freq: 349.23, solfege: 'Fa',  note: 'F'),
  PianoKey(name: 'F#4', freq: 369.99, solfege: 'Fi',  note: 'F#', isBlack: true),
  PianoKey(name: 'G4',  freq: 392.00, solfege: 'Sol', note: 'G'),
  PianoKey(name: 'G#4', freq: 415.30, solfege: 'Si',  note: 'G#', isBlack: true),
  PianoKey(name: 'A4',  freq: 440.00, solfege: 'La',  note: 'A'),
  PianoKey(name: 'A#4', freq: 466.16, solfege: 'Li',  note: 'A#', isBlack: true),
  PianoKey(name: 'B4',  freq: 493.88, solfege: 'Ti',  note: 'B'),
  PianoKey(name: 'C5',  freq: 523.25, solfege: 'Do',  note: 'C'),
];
