/// Data models for a completed karaoke session and its analysis results.
library;

import 'song.dart';
import 'pitch_frame.dart';

enum FrameJudgment { correct, flat, sharp, missed, rest }

class FrameResult {
  final PitchFrame frame;
  final ReferenceNote? reference;
  final FrameJudgment judgment;
  final double centsOff;

  const FrameResult({
    required this.frame,
    this.reference,
    required this.judgment,
    this.centsOff = 0,
  });
}

// ─── AI feedback models ───────────────────────────────────────────────────────

class ImprovementItem {
  final String issue;
  final String detail;
  final String? timeHint;

  const ImprovementItem({
    required this.issue,
    required this.detail,
    this.timeHint,
  });
}

class FeedbackResult {
  final String overallMessage;
  final List<String> strengths;
  final List<ImprovementItem> improvements;
  final String tip;

  const FeedbackResult({
    required this.overallMessage,
    required this.strengths,
    required this.improvements,
    required this.tip,
  });
}

// ─── Section and session aggregates ──────────────────────────────────────────

class SectionResult {
  final String sectionName;
  final int startMs;
  final int endMs;
  final List<FrameResult> frames;

  const SectionResult({
    required this.sectionName,
    required this.startMs,
    required this.endMs,
    required this.frames,
  });

  int get total => frames.length;
  int get correctCount =>
      frames.where((f) => f.judgment == FrameJudgment.correct).length;
  int get flatCount =>
      frames.where((f) => f.judgment == FrameJudgment.flat).length;
  int get sharpCount =>
      frames.where((f) => f.judgment == FrameJudgment.sharp).length;
  int get missedCount =>
      frames.where((f) => f.judgment == FrameJudgment.missed).length;

  double get score {
    if (total == 0) return 0;
    return ((correctCount + (flatCount + sharpCount) * 0.4) / total * 100)
        .clamp(0, 100);
  }

  double get avgCentsOff {
    final relevant = frames
        .where((f) => f.reference != null && f.frame.hasPitch)
        .toList();
    if (relevant.isEmpty) return 0;
    return relevant.map((f) => f.centsOff).reduce((a, b) => a + b) /
        relevant.length;
  }
}

class SessionResult {
  final Song song;
  final List<FrameResult> allFrames;
  final List<SectionResult> sections;
  final FeedbackResult? aiFeedback;

  const SessionResult({
    required this.song,
    required this.allFrames,
    required this.sections,
    this.aiFeedback,
  });

  double get overallScore {
    if (allFrames.isEmpty) return 0;
    final scored = allFrames.where((f) => f.reference != null).toList();
    if (scored.isEmpty) return 0;
    final correct = scored
        .where((f) => f.judgment == FrameJudgment.correct)
        .length;
    final partial =
        scored
            .where(
              (f) =>
                  f.judgment == FrameJudgment.flat ||
                  f.judgment == FrameJudgment.sharp,
            )
            .length *
        0.4;
    return ((correct + partial) / scored.length * 100).clamp(0, 100);
  }

  double get avgCentsOff {
    final relevant = allFrames
        .where((f) => f.reference != null && f.frame.hasPitch)
        .toList();
    if (relevant.isEmpty) return 0;
    return relevant.map((f) => f.centsOff).reduce((a, b) => a + b) /
        relevant.length;
  }

  SessionResult withFeedback(FeedbackResult feedback) => SessionResult(
    song: song,
    allFrames: allFrames,
    sections: sections,
    aiFeedback: feedback,
  );
}
