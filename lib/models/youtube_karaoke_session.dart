class YouTubeKaraokeSession {
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final Duration videoDuration;
  final List<TimedLyricLine> lyrics;
  final DateTime startedAt;

  YouTubeKaraokeSession({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.videoDuration,
    required this.lyrics,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();
}

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
