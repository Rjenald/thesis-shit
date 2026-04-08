/// A single captured pitch measurement with its song-relative timestamp.
library;

class PitchFrame {
  final int timestampMs; // offset from song start
  final double frequencyHz; // 0.0 when no pitch detected
  final double confidence; // 0.0–1.0

  const PitchFrame({
    required this.timestampMs,
    required this.frequencyHz,
    this.confidence = 1.0,
  });

  bool get hasPitch => frequencyHz > 50 && confidence > 0.5;
}
