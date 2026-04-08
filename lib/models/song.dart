/// Represents a reference song with note timeline and section structure.
library;

import 'dart:math';

class ReferenceNote {
  final int startMs;
  final int endMs;
  final int midiNote;
  final String lyricWord;

  const ReferenceNote({
    required this.startMs,
    required this.endMs,
    required this.midiNote,
    required this.lyricWord,
  });

  double get frequencyHz => 440.0 * pow(2, (midiNote - 69) / 12.0);

  bool containsTime(int ms) => ms >= startMs && ms < endMs;

  String get noteName {
    const names = [
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
    return '${names[midiNote % 12]}${(midiNote ~/ 12) - 1}';
  }
}

class SongSection {
  final String name;
  final int startMs;
  final int endMs;

  const SongSection({
    required this.name,
    required this.startMs,
    required this.endMs,
  });
}

class Song {
  final String id;
  final String title;
  final String artist;
  final int bpm;
  final List<ReferenceNote> notes;
  final List<SongSection> sections;
  final int durationMs;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.bpm,
    required this.notes,
    required this.sections,
    required this.durationMs,
  });

  ReferenceNote? noteAt(int ms) {
    for (final note in notes) {
      if (note.containsTime(ms)) return note;
    }
    return null;
  }

  SongSection? sectionAt(int ms) {
    for (final section in sections) {
      if (ms >= section.startMs && ms < section.endMs) return section;
    }
    return null;
  }

  int get minMidi => notes.map((n) => n.midiNote).reduce(min);
  int get maxMidi => notes.map((n) => n.midiNote).reduce(max);
}
