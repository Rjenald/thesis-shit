/// Static song catalogue — reference note timelines for demo songs.
/// At 100 BPM: quarter note = 600 ms, half note = 1200 ms.
library;

import '../models/song.dart';

// ─── MIDI note numbers ────────────────────────────────────────────────────────
const _c4 = 60, _d4 = 62, _e4 = 64, _f4 = 65;
const _g4 = 67, _a4 = 69;

// ─── Duration constants (ms @ 100 BPM) ───────────────────────────────────────
const _q = 600; // quarter note
const _h = 1200; // half note

// ─── Helper: build ordered note list from specs ───────────────────────────────
List<ReferenceNote> _build(List<(int midi, int durMs, String lyric)> specs) {
  int cursor = 0;
  return specs.map((s) {
    final note = ReferenceNote(
      startMs: cursor,
      endMs: cursor + s.$2,
      midiNote: s.$1,
      lyricWord: s.$3,
    );
    cursor += s.$2;
    return note;
  }).toList();
}

// ─── Twinkle Twinkle Little Star ─────────────────────────────────────────────
// 6 lines × (6 quarters + 1 half) = 6 × 4800 ms = 28 800 ms total

final _twinkleNotes = _build([
  // Verse 1 — "Twinkle twinkle little star"
  (_c4, _q, 'Twin-'), (_c4, _q, '-kle'), (_g4, _q, 'twin-'), (_g4, _q, '-kle'),
  (_a4, _q, 'lit-'), (_a4, _q, '-tle'), (_g4, _h, 'star'),
  // Verse 1 — "How I wonder what you are"
  (_f4, _q, 'How'), (_f4, _q, 'I'), (_e4, _q, 'won-'), (_e4, _q, '-der'),
  (_d4, _q, 'what'), (_d4, _q, 'you'), (_c4, _h, 'are'),
  // Bridge — "Up above the world so high"
  (_g4, _q, 'Up'), (_g4, _q, 'a-'), (_f4, _q, '-bove'), (_f4, _q, 'the'),
  (_e4, _q, 'world'), (_e4, _q, 'so'), (_d4, _h, 'high'),
  // Bridge — "Like a diamond in the sky"
  (_g4, _q, 'Like'), (_g4, _q, 'a'), (_f4, _q, 'dia-'), (_f4, _q, '-mond'),
  (_e4, _q, 'in'), (_e4, _q, 'the'), (_d4, _h, 'sky'),
  // Verse 2 — repeat "Twinkle twinkle little star"
  (_c4, _q, 'Twin-'), (_c4, _q, '-kle'), (_g4, _q, 'twin-'), (_g4, _q, '-kle'),
  (_a4, _q, 'lit-'), (_a4, _q, '-tle'), (_g4, _h, 'star'),
  // Verse 2 — repeat "How I wonder what you are"
  (_f4, _q, 'How'), (_f4, _q, 'I'), (_e4, _q, 'won-'), (_e4, _q, '-der'),
  (_d4, _q, 'what'), (_d4, _q, 'you'), (_c4, _h, 'are'),
]);

final kTwinkleSong = Song(
  id: 'twinkle',
  title: 'Twinkle Twinkle Little Star',
  artist: 'Traditional',
  bpm: 100,
  notes: _twinkleNotes,
  sections: const [
    SongSection(name: 'Verse 1', startMs: 0, endMs: 9600),
    SongSection(name: 'Bridge', startMs: 9600, endMs: 19200),
    SongSection(name: 'Verse 2', startMs: 19200, endMs: 28800),
  ],
  durationMs: 28800,
);

// ─── Mary Had a Little Lamb ───────────────────────────────────────────────────

final _maryNotes = _build([
  // "Mary had a little lamb"
  (_e4, _q, 'Ma-'), (_d4, _q, '-ry'), (_c4, _q, 'had'), (_d4, _q, 'a'),
  (_e4, _q, 'lit-'), (_e4, _q, '-tle'), (_e4, _h, 'lamb'),
  // "little lamb, little lamb"
  (_d4, _q, 'lit-'), (_d4, _q, '-tle'), (_d4, _h, 'lamb'),
  (_e4, _q, 'lit-'), (_g4, _q, '-tle'), (_g4, _h, 'lamb'),
  // "Mary had a little lamb"
  (_e4, _q, 'Ma-'), (_d4, _q, '-ry'), (_c4, _q, 'had'), (_d4, _q, 'a'),
  (_e4, _q, 'lit-'), (_e4, _q, '-tle'), (_e4, _q, 'lamb'), (_e4, _q, 'its'),
  // "fleece was white as snow"
  (_d4, _q, 'fleece'), (_d4, _q, 'was'), (_e4, _q, 'white'), (_d4, _q, 'as'),
  (_c4, _h + _h, 'snow'),
]);

final _maryDuration = _maryNotes.last.endMs;

final kMarySong = Song(
  id: 'mary',
  title: 'Mary Had a Little Lamb',
  artist: 'Traditional',
  bpm: 100,
  notes: _maryNotes,
  sections: [
    const SongSection(name: 'Phrase 1', startMs: 0, endMs: 4800),
    const SongSection(name: 'Phrase 2', startMs: 4800, endMs: 9600),
    SongSection(name: 'Phrase 3', startMs: 9600, endMs: _maryDuration),
  ],
  durationMs: _maryDuration,
);

// ─── Catalogue ────────────────────────────────────────────────────────────────
final List<Song> kSongCatalogue = [kTwinkleSong, kMarySong];
