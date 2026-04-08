/// Compares a captured list of PitchFrames against a Song's reference notes
/// and produces a SessionResult with per-frame and per-section judgments.
library;

import 'dart:math' as math;

import '../models/pitch_frame.dart';
import '../models/session_result.dart';
import '../models/song.dart';

class SessionAnalyzer {
  static const double _correctCents = 25.0;

  SessionResult analyze(Song song, List<PitchFrame> frames) {
    if (frames.isEmpty) {
      return SessionResult(
        song: song,
        allFrames: const [],
        sections: song.sections
            .map(
              (s) => SectionResult(
                sectionName: s.name,
                startMs: s.startMs,
                endMs: s.endMs,
                frames: const [],
              ),
            )
            .toList(),
      );
    }

    final frameResults = frames.map((f) => _judgeFrame(f, song)).toList();

    final sectionResults = song.sections.map((section) {
      final sectionFrames = frameResults
          .where(
            (r) =>
                r.frame.timestampMs >= section.startMs &&
                r.frame.timestampMs < section.endMs,
          )
          .toList();
      return SectionResult(
        sectionName: section.name,
        startMs: section.startMs,
        endMs: section.endMs,
        frames: sectionFrames,
      );
    }).toList();

    return SessionResult(
      song: song,
      allFrames: frameResults,
      sections: sectionResults,
    );
  }

  FrameResult _judgeFrame(PitchFrame frame, Song song) {
    final ref = song.noteAt(frame.timestampMs);

    if (!frame.hasPitch) {
      return FrameResult(
        frame: frame,
        reference: ref,
        judgment: ref != null ? FrameJudgment.missed : FrameJudgment.rest,
      );
    }

    if (ref == null) {
      return FrameResult(frame: frame, judgment: FrameJudgment.rest);
    }

    // Check direct pitch and octave-shifted alternatives to handle octave errors
    final cents = _cents(frame.frequencyHz, ref.frequencyHz);
    final centsUp = _cents(frame.frequencyHz * 2, ref.frequencyHz);
    final centsDown = _cents(frame.frequencyHz / 2, ref.frequencyHz);

    double best = cents;
    if (centsUp.abs() < best.abs()) best = centsUp;
    if (centsDown.abs() < best.abs()) best = centsDown;

    final FrameJudgment judgment;
    if (best.abs() <= _correctCents) {
      judgment = FrameJudgment.correct;
    } else if (best > 0) {
      judgment = FrameJudgment.sharp;
    } else {
      judgment = FrameJudgment.flat;
    }

    return FrameResult(
      frame: frame,
      reference: ref,
      judgment: judgment,
      centsOff: best,
    );
  }

  double _cents(double userHz, double refHz) {
    if (userHz <= 0 || refHz <= 0) return 0;
    return 1200 * math.log(userHz / refHz) / math.log(2);
  }
}
