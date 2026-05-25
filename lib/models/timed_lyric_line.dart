class TimedLyricLine {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final double targetPitch;

  TimedLyricLine({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.targetPitch = 0.0,
  });

  bool isActive(Duration currentTime) =>
      currentTime >= startTime && currentTime < endTime;
}
