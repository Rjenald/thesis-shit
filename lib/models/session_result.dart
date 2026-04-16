/// Data models for a completed karaoke session.
/// LyricPitchData holds raw pitch readings per lyric line.
/// SessionResult aggregates all lines into scores, health alerts, and recommendations.
library;

enum LineStatus { correct, flat, sharp, noSignal }

class LyricPitchData {
  final String lyricText;

  /// Hz readings captured during this lyric line. 0 = no signal.
  final List<double> pitchReadings;

  /// Cents deviation per reading (positive = sharp, negative = flat, 0 = silence).
  final List<double> centsReadings;

  const LyricPitchData({
    required this.lyricText,
    required this.pitchReadings,
    required this.centsReadings,
  });

  /// Fraction of readings where voice was detected (pitch > 0).
  double get voiceActivityRate {
    if (pitchReadings.isEmpty) return 0;
    return pitchReadings.where((p) => p > 0).length / pitchReadings.length;
  }

  List<double> get _activeCents =>
      centsReadings.where((c) => c.abs() > 0.5).toList();

  /// Mean cents deviation across voiced frames.
  double get avgCents {
    final a = _activeCents;
    if (a.isEmpty) return 0;
    return a.reduce((x, y) => x + y) / a.length;
  }

  /// % of voiced frames that were flat (< −15 cents).
  double get flatPercent {
    final a = _activeCents;
    if (a.isEmpty) return 0;
    return a.where((c) => c < -15).length / a.length * 100;
  }

  /// % of voiced frames that were sharp (> +15 cents).
  double get sharpPercent {
    final a = _activeCents;
    if (a.isEmpty) return 0;
    return a.where((c) => c > 15).length / a.length * 100;
  }

  /// % of voiced frames that were in tune (±15 cents).
  double get inTunePercent {
    final a = _activeCents;
    if (a.isEmpty) return 0;
    return a.where((c) => c.abs() <= 15).length / a.length * 100;
  }

  LineStatus get status {
    if (lyricText.isEmpty) return LineStatus.noSignal;
    if (voiceActivityRate < 0.15) return LineStatus.noSignal;
    if (flatPercent > 50) return LineStatus.flat;
    if (sharpPercent > 50) return LineStatus.sharp;
    if (inTunePercent >= 40) return LineStatus.correct;
    return flatPercent >= sharpPercent ? LineStatus.flat : LineStatus.sharp;
  }

  Map<String, dynamic> toJson() => {
        'lyricText': lyricText,
        'pitchReadings': pitchReadings,
        'centsReadings': centsReadings,
      };

  factory LyricPitchData.fromJson(Map<String, dynamic> j) => LyricPitchData(
        lyricText: j['lyricText'] as String? ?? '',
        pitchReadings: (j['pitchReadings'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
        centsReadings: (j['centsReadings'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
      );
}

class SessionResult {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final DateTime completedAt;
  final List<LyricPitchData> lyricResults;
  final int durationSeconds;

  const SessionResult({
    required this.songTitle,
    required this.songArtist,
    required this.songImage,
    required this.completedAt,
    required this.lyricResults,
    required this.durationSeconds,
  });

  /// Only lines that have actual lyric text.
  List<LyricPitchData> get singableLines =>
      lyricResults.where((l) => l.lyricText.isNotEmpty).toList();

  int get correctLines =>
      singableLines.where((l) => l.status == LineStatus.correct).length;
  int get flatLines =>
      singableLines.where((l) => l.status == LineStatus.flat).length;
  int get sharpLines =>
      singableLines.where((l) => l.status == LineStatus.sharp).length;
  int get noSignalLines =>
      singableLines.where((l) => l.status == LineStatus.noSignal).length;
  int get totalLines => singableLines.length;

  /// Score = correct / (total lines that had a detectable signal).
  double get score {
    if (totalLines == 0) return 0;
    final active =
        singableLines.where((l) => l.status != LineStatus.noSignal).length;
    if (active == 0) return 0;
    return (correctLines / active * 100).clamp(0.0, 100.0);
  }

  double get overallVoiceActivity {
    if (singableLines.isEmpty) return 0;
    return singableLines
            .map((l) => l.voiceActivityRate)
            .reduce((a, b) => a + b) /
        singableLines.length;
  }

  double get avgFlatPercent {
    final lines =
        singableLines.where((l) => l.voiceActivityRate > 0.15).toList();
    if (lines.isEmpty) return 0;
    return lines.map((l) => l.flatPercent).reduce((a, b) => a + b) /
        lines.length;
  }

  double get avgSharpPercent {
    final lines =
        singableLines.where((l) => l.voiceActivityRate > 0.15).toList();
    if (lines.isEmpty) return 0;
    return lines.map((l) => l.sharpPercent).reduce((a, b) => a + b) /
        lines.length;
  }

  int get stars {
    final s = score;
    if (s >= 95) return 5;
    if (s >= 80) return 4;
    if (s >= 65) return 3;
    if (s >= 50) return 2;
    return 1;
  }

  /// Heuristic (non-diagnostic) vocal health alerts.
  List<String> get vocalHealthAlerts {
    final alerts = <String>[];
    if (avgFlatPercent > 55) {
      alerts.add(
          'Consistent flat singing detected — may indicate low breath support. '
          'Practice diaphragmatic breathing and support exercises.');
    }
    if (avgSharpPercent > 55) {
      alerts.add(
          'Consistent sharp singing detected — may indicate vocal tension. '
          'Practice relaxation and gentle warm-up exercises before your next session.');
    }
    if (overallVoiceActivity < 0.25 && totalLines > 3) {
      alerts.add(
          'Low vocal signal detected. Ensure your microphone is enabled and '
          'you are singing at a consistent volume close to the device.');
    }
    if (durationSeconds > 240 &&
        (avgFlatPercent > 40 || avgSharpPercent > 40)) {
      alerts.add(
          'Extended singing with pitch drift detected — possible vocal fatigue. '
          'Rest your voice for 10–15 minutes before continuing. '
          '(Non-diagnostic alert — consult a vocal coach for persistent issues.)');
    }
    return alerts;
  }

  /// Targeted lyric-level practice recommendations.
  List<String> get practiceRecommendations {
    final recs = <String>[];
    if (avgFlatPercent > 35) {
      recs.add(
          '${avgFlatPercent.toStringAsFixed(0)}% of phrases were flat — '
          'try Drill #1: Ascending Scale Exercises to strengthen pitch support.');
    }
    if (avgSharpPercent > 35) {
      recs.add(
          '${avgSharpPercent.toStringAsFixed(0)}% of phrases were sharp — '
          'try Drill #2: Relaxed Tone Exercises to reduce vocal tension.');
    }
    final problemLines = singableLines
        .where(
            (l) => l.status == LineStatus.flat || l.status == LineStatus.sharp)
        .take(2)
        .toList();
    for (final line in problemLines) {
      final type = line.status == LineStatus.flat ? 'flat' : 'sharp';
      final excerpt = line.lyricText.length > 38
          ? '${line.lyricText.substring(0, 38)}…'
          : line.lyricText;
      recs.add(
          'Loop: "$excerpt" was $type '
          '(avg ${line.avgCents.abs().toStringAsFixed(0)} cents off) — try Drill #3.');
    }
    if (recs.isEmpty) {
      recs.add(
          'Excellent performance! Try Drill #3: Vibrato Control Exercises '
          'to add expressive nuance to your singing.');
    }
    return recs;
  }

  Map<String, dynamic> toJson() => {
        'songTitle': songTitle,
        'songArtist': songArtist,
        'songImage': songImage,
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'lyricResults': lyricResults.map((l) => l.toJson()).toList(),
      };

  factory SessionResult.fromJson(Map<String, dynamic> j) => SessionResult(
        songTitle: j['songTitle'] as String? ?? '',
        songArtist: j['songArtist'] as String? ?? '',
        songImage: j['songImage'] as String? ?? '',
        completedAt:
            DateTime.tryParse(j['completedAt'] as String? ?? '') ??
                DateTime.now(),
        durationSeconds: j['durationSeconds'] as int? ?? 0,
        lyricResults: (j['lyricResults'] as List<dynamic>?)
                ?.map((e) =>
                    LyricPitchData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
