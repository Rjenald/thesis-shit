/// Piano sound, synthesised in Dart so no audio assets have to ship.
///
/// The keyboard used to be decorative — a [CustomPaint] that lit up a key
/// when the microphone heard that pitch, with no gesture handling at all,
/// so pressing a key did nothing. This is what makes it playable.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

// ── WAV synthesis ─────────────────────────────────────────────────────────────

/// Relative strength of each harmonic, fundamental first.
///
/// Rolling off steeply is what keeps it from sounding like an organ. The
/// earlier version used three partials at 0.55/0.25/0.10 with no decay at
/// all, which is a sustained tone: the ear reads a flat envelope as a
/// blown or bowed instrument, never a struck one.
const List<double> _partialGain = [1.00, 0.50, 0.28, 0.16, 0.09, 0.05];

/// Generates a piano-like WAV buffer for [hz], [ms] long.
///
/// Three things make this read as a struck string rather than a tone:
///
///  - **exponential decay**, because a piano has no sustain of its own.
///    This is the single biggest cue and the one that was missing.
///  - **faster decay for higher partials**, which is why a piano sounds
///    bright at the attack and mellow a moment later. A fixed harmonic
///    mix cannot do that.
///  - **a 4ms attack**, about what a hammer strike takes. 20ms reads as a
///    swell.
///
/// Decay also shortens as pitch rises, as it does on a real instrument —
/// the top octave dies away far quicker than the bottom.
Uint8List makePianoWav(double hz, {int ms = 1200}) {
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

  final attack = max(1, (sr * 0.004).round());
  // Seconds for the fundamental to fall to 1/e. Scaled by pitch: a low
  // string rings, a high one does not.
  final tau = 0.9 * pow(440.0 / hz, 0.45).toDouble();
  // Whatever the note, bring it to silence by the end of the buffer so a
  // released key never clicks.
  final fadeFrom = (n * 0.88).round();

  // Peak at t=0 is every partial in phase, so normalise by their sum
  // rather than hoping. 0.72 leaves headroom for two keys at once.
  final norm = 0.72 / _partialGain.reduce((a, b) => a + b);

  for (int i = 0; i < n; i++) {
    final t = i / sr;
    double v = 0;
    for (int k = 0; k < _partialGain.length; k++) {
      final partialHz = hz * (k + 1);
      if (partialHz > sr / 2) break; // never alias
      // Higher partials die faster: that decay spread IS the timbre.
      final decay = exp(-t / (tau / (1 + 0.55 * k)));
      v += _partialGain[k] * decay * sin(2 * pi * partialHz * t);
    }

    double env = 1.0;
    if (i < attack) env = i / attack;
    if (i > fadeFrom) env *= (n - i) / (n - fadeFrom);

    final s = (env * v * norm * 32767).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, s, Endian.little);
  }
  return buf.buffer.asUint8List();
}

// ── just_audio source ─────────────────────────────────────────────────────────

/// Feeds an in-memory WAV buffer to just_audio.
///
/// Kept for callers that want to play a one-off frequency. [PianoSoundPool]
/// uses temp files instead, because a `StreamAudioSource` is re-read on
/// every play and that latency is audible under a finger.
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

// ── playback ──────────────────────────────────────────────────────────────────

/// Plays piano notes with enough speed and overlap to be played on.
///
/// Two things a single [AudioPlayer] cannot do, both of which make a
/// keyboard feel broken:
///
///  - **overlap.** One player stops the previous note to start the next,
///    so a run of keys becomes a stutter and two keys at once is
///    impossible. A small ring of players lets notes ring over each other.
///  - **respond at once.** Synthesising ~1.2s of audio per press and
///    handing it over as a stream is audibly late. Every note is rendered
///    to a temp file up front instead, so a press is just a seek and a
///    play.
///
/// Rendering the octave takes well under a second and happens off the
/// first frame, so a key pressed before [ready] completes is simply
/// ignored rather than queued — a note that arrives half a second late is
/// worse than one that never sounds.
class PianoSoundPool {
  PianoSoundPool({this.voices = 6});

  /// How many notes may ring at once. Six covers a chord plus a fast run;
  /// beyond that the oldest is cut short, which is what a sustain pedal
  /// release sounds like anyway.
  final int voices;

  final Map<int, String> _paths = {};
  final List<AudioPlayer> _players = [];

  /// Which note each voice currently holds, so a repeat can skip the load.
  final List<String?> _loaded = [];
  int _next = 0;
  bool _ready = false;
  bool _disposed = false;
  Future<void>? _loading;

  bool get isReady => _ready;

  /// Renders every key once and creates the players. Safe to call twice.
  Future<void> ready({List<PianoKey> keys = pianoOctaveKeys}) {
    return _loading ??= _load(keys);
  }

  Future<void> _load(List<PianoKey> keys) async {
    try {
      final dir = await getTemporaryDirectory();
      final root = Directory('${dir.path}/huni_piano');
      if (!root.existsSync()) root.createSync(recursive: true);

      for (final key in keys) {
        final midi = midiForFrequency(key.freq);
        final file = File('${root.path}/note_$midi.wav');
        // Re-rendering on every launch would be wasted work, but a stale
        // file from an older, worse-sounding synthesis would be worse —
        // so the filename carries the synthesis version.
        final versioned = File('${root.path}/v2_note_$midi.wav');
        if (file.existsSync()) file.deleteSync();
        if (!versioned.existsSync()) {
          versioned.writeAsBytesSync(makePianoWav(key.freq));
        }
        _paths[midi] = versioned.path;
      }

      for (var i = 0; i < voices; i++) {
        _players.add(AudioPlayer());
        _loaded.add(null);
      }
      _ready = !_disposed;
    } catch (e) {
      // A keyboard that lights up but stays silent is a degraded feature,
      // not a broken screen, so this never throws at the UI.
      debugPrint('PianoSoundPool failed to load: $e');
      _ready = false;
    }
  }

  /// Plays [midi] if it is one of the rendered keys. Returns false when
  /// nothing sounded, so a caller can decide whether to say so.
  Future<bool> play(int midi) async {
    if (!_ready || _disposed) return false;
    final path = _paths[midi];
    if (path == null) return false;
    final slot = _next % _players.length;
    _next++;
    final player = _players[slot];
    try {
      // Reloading the file on every press is the latency this pool
      // exists to avoid, so a voice that already holds this note just
      // seeks back to the start. Tracked here rather than read off the
      // player: `audioSource` carries no tag for a file path.
      if (_loaded[slot] != path) {
        await player.setFilePath(path);
        _loaded[slot] = path;
      }
      await player.seek(Duration.zero);
      unawaited(player.play());
      return true;
    } catch (e) {
      debugPrint('PianoSoundPool.play($midi) failed: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _ready = false;
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {
        // Disposing twice, or after the engine is gone, is not worth
        // reporting.
      }
    }
    _players.clear();
    _loaded.clear();
  }
}

// ── Piano key data ────────────────────────────────────────────────────────────

/// MIDI number for a frequency, rounded to the nearest semitone.
int midiForFrequency(double hz) =>
    (69 + 12 * (log(hz / 440.0) / ln2)).round();

/// Equal-tempered frequency for a MIDI number.
double frequencyForMidi(int midi) => 440.0 * pow(2, (midi - 69) / 12).toDouble();

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

  int get midi => midiForFrequency(freq);
}

/// One octave C4→C5 with correct solfège labels (movable Do).
const List<PianoKey> pianoOctaveKeys = [
  PianoKey(name: 'C4', freq: 261.63, solfege: 'Do', note: 'C'),
  PianoKey(name: 'C#4', freq: 277.18, solfege: 'Di', note: 'C#', isBlack: true),
  PianoKey(name: 'D4', freq: 293.66, solfege: 'Re', note: 'D'),
  PianoKey(name: 'D#4', freq: 311.13, solfege: 'Ri', note: 'D#', isBlack: true),
  PianoKey(name: 'E4', freq: 329.63, solfege: 'Mi', note: 'E'),
  PianoKey(name: 'F4', freq: 349.23, solfege: 'Fa', note: 'F'),
  PianoKey(name: 'F#4', freq: 369.99, solfege: 'Fi', note: 'F#', isBlack: true),
  PianoKey(name: 'G4', freq: 392.00, solfege: 'Sol', note: 'G'),
  PianoKey(name: 'G#4', freq: 415.30, solfege: 'Si', note: 'G#', isBlack: true),
  PianoKey(name: 'A4', freq: 440.00, solfege: 'La', note: 'A'),
  PianoKey(name: 'A#4', freq: 466.16, solfege: 'Li', note: 'A#', isBlack: true),
  PianoKey(name: 'B4', freq: 493.88, solfege: 'Ti', note: 'B'),
  PianoKey(name: 'C5', freq: 523.25, solfege: 'Do', note: 'C'),
];
