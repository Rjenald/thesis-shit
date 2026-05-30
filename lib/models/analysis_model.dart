class Note {
  final double time;
  final String note;
  Note({required this.time, required this.note});
}

class WordAnalysis {
  final String word;
  final double start;
  final double end;
  final List<Note> notes;

  WordAnalysis({
    required this.word,
    required this.start,
    required this.end,
    required this.notes,
  });
}
