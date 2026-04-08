/// Simulates the backend AI pipeline (Whisper + GPT-4) with a network-like
/// delay. Generates feedback from real session data so results are meaningful.
///
/// Replace the body of [generateFeedback] with an HTTP call to your backend
/// once it is ready — the interface stays the same.
library;

import 'dart:math';

import '../models/session_result.dart';

class MockFeedbackService {
  final _rng = Random();

  Future<FeedbackResult> generateFeedback(SessionResult session) async {
    // Simulate Whisper transcription + GPT-4 round-trip (~1.5–2.5 s)
    await Future.delayed(Duration(milliseconds: 1500 + _rng.nextInt(1000)));

    final score = session.overallScore;
    final avgCents = session.avgCentsOff;
    final sections = session.sections.where((s) => s.total > 0).toList();

    final sorted = [...sections]..sort((a, b) => a.score.compareTo(b.score));

    final worst = sorted.isNotEmpty ? sorted.first : null;
    final best = sorted.isNotEmpty ? sorted.last : null;

    final tendFlat = avgCents < -15;
    final tendSharp = avgCents > 15;
    final missedRatio = session.allFrames.isEmpty
        ? 0.0
        : session.allFrames
                  .where((f) => f.judgment == FrameJudgment.missed)
                  .length /
              session.allFrames.length;

    return FeedbackResult(
      overallMessage: _overallMessage(score),
      strengths: _strengths(score, best, sections),
      improvements: _improvements(
        avgCents,
        tendFlat,
        tendSharp,
        worst,
        missedRatio,
      ),
      tip: _tip(score, tendFlat, tendSharp, missedRatio),
    );
  }

  // ── Message generators ──────────────────────────────────────────────────────

  String _overallMessage(double score) {
    if (score >= 88) {
      return 'Excellent performance! Your pitch control is very solid.';
    }
    if (score >= 72) {
      return 'Good effort — strong in most sections with a few spots to refine.';
    }
    if (score >= 55) {
      return 'Decent attempt — with focused practice you\'ll improve quickly.';
    }
    if (score >= 35) {
      return 'Keep at it — the foundation is there, just needs more repetition.';
    }
    return 'Early days yet — try humming along first to lock in the melody.';
  }

  List<String> _strengths(
    double score,
    SectionResult? best,
    List<SectionResult> sections,
  ) {
    final out = <String>[];
    if (best != null && best.score >= 70) {
      out.add(
        '${best.sectionName} was your strongest section '
        '(${best.score.toStringAsFixed(0)}% accuracy)',
      );
    }
    final goodCount = sections.where((s) => s.score >= 75).length;
    if (goodCount >= 2) {
      out.add('Consistent pitch across $goodCount sections of the song');
    }
    if (score >= 65) out.add('Good overall pitch awareness throughout');
    if (out.isEmpty) out.add('You completed the full song — great effort!');
    return out;
  }

  List<ImprovementItem> _improvements(
    double avgCents,
    bool flat,
    bool sharp,
    SectionResult? worst,
    double missedRatio,
  ) {
    final out = <ImprovementItem>[];

    if (flat) {
      out.add(
        ImprovementItem(
          issue: 'Singing flat',
          detail:
              'Your pitch averaged ${avgCents.abs().toStringAsFixed(0)} cents '
              'below target. Try projecting a little more and keep your chin '
              'slightly up when reaching for higher notes.',
          timeHint: worst != null
              ? 'Most noticeable in ${worst.sectionName}'
              : null,
        ),
      );
    } else if (sharp) {
      out.add(
        ImprovementItem(
          issue: 'Singing sharp',
          detail:
              'Your pitch averaged ${avgCents.toStringAsFixed(0)} cents above '
              'target. Relax your throat and support breath from the diaphragm '
              'rather than pushing from the chest.',
          timeHint: worst != null
              ? 'Most noticeable in ${worst.sectionName}'
              : null,
        ),
      );
    }

    if (worst != null && worst.score < 65) {
      out.add(
        ImprovementItem(
          issue: 'Weak section: ${worst.sectionName}',
          detail:
              'This section scored ${worst.score.toStringAsFixed(0)}% — '
              'isolate it and practise slowly until the melody feels natural.',
          timeHint: '${_ts(worst.startMs)} – ${_ts(worst.endMs)}',
        ),
      );
    }

    if (missedRatio > 0.2) {
      out.add(
        ImprovementItem(
          issue: 'Missed or short notes',
          detail:
              'Some expected notes were not detected. Sustain each note for '
              'its full duration and avoid trailing off at the end of phrases.',
          timeHint: null,
        ),
      );
    }

    if (out.isEmpty) {
      out.add(
        ImprovementItem(
          issue: 'Minor pitch inconsistency',
          detail:
              'Small deviations throughout — nothing major. Continued '
              'practice will tighten this up naturally.',
          timeHint: null,
        ),
      );
    }

    return out;
  }

  String _tip(double score, bool flat, bool sharp, double missedRatio) {
    if (missedRatio > 0.3) {
      return 'Learn the melody by ear first — hum it without words until it '
          'feels comfortable, then add the lyrics.';
    }
    if (flat) {
      return 'Record yourself and play it back next to the reference. '
          'Hearing the gap trains your ear faster than any other exercise.';
    }
    if (sharp) {
      return 'Slow it down and sing softer — sharpness usually comes from '
          'tension. A relaxed voice finds the right pitch more easily.';
    }
    if (score < 60) {
      return 'Practise at half tempo with no guide. Nailing the slow version '
          'makes the real speed much easier.';
    }
    return 'Try again immediately — repetition right after receiving feedback '
        'is the single most effective way to improve quickly.';
  }

  String _ts(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
