import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/note_utils.dart' show PitchFeedback;
import '../core/singing_segment_builder.dart'
    show
        LyricLineSegments,
        groupSegmentsByLyricLine,
        groupSingingSegmentsIntoPhrases,
        groupSegmentsByRecognizedWord;
import '../models/singing_segment.dart';
import '../services/lyrics_service.dart' show LrcLine;
import 'singing_segment_detail_sheet.dart';

const _inTuneColor = Color(0xFF4CAF50);
const _flatColor = Color(0xFF448AFF);
const _sharpColor = Color(0xFFFF5252);
const _noSignalColor = Color(0xFF757575);

Color _colorFor(PitchFeedback status) {
  switch (status) {
    case PitchFeedback.correct:
      return _inTuneColor;
    case PitchFeedback.tooLow:
      return _flatColor;
    case PitchFeedback.tooHigh:
      return _sharpColor;
    case PitchFeedback.noSignal:
      return _noSignalColor;
  }
}

String _glyphFor(PitchFeedback status) {
  switch (status) {
    case PitchFeedback.correct:
      return '✓';
    case PitchFeedback.tooLow:
      return '↓';
    case PitchFeedback.tooHigh:
      return '↑';
    case PitchFeedback.noSignal:
      return '–';
  }
}

String _formatClockTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final m = totalSeconds ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Karaoke's synchronized target-vs-actual pitch timeline: the whole
/// recording session, grouped into readable chronological phrases, each
/// showing the word actually sung — once, like a lyric — next to the small
/// per-syllable target/actual/status chips behind it. Tap any chip for the
/// full detail (exact cents, confidence, time range, pitch movement).
/// Renders nothing if [segments] is empty (most songs don't have a
/// ground-truth melody yet) — the karaoke-only comparison this drives
/// never applies to "without karaoke" mode's plain word/note timeline.
///
/// Rendered as a plain (non-scrolling) Column, not its own ListView — the
/// caller (ResultsPage) already puts this inside one outer scrollable
/// list, and nesting scrollables is more trouble than it's worth here.
class PitchTimelineView extends StatelessWidget {
  final List<SingingSegment> segments;

  /// The song's own timed lyric lines, used purely to group the timeline
  /// into lyric-line sections so it reads like a lyric sheet. Optional —
  /// with no lyrics available this falls back to grouping by natural pauses
  /// ([groupSingingSegmentsIntoPhrases]), which is still chronological and
  /// readable, just not aligned to the song's actual lines.
  final List<LrcLine> lyrics;

  const PitchTimelineView({
    super.key,
    required this.segments,
    this.lyrics = const [],
  });

  /// One section per lyric line when lyrics are available, otherwise one
  /// per natural-pause phrase — both collapse to the same shape so the
  /// rendering below doesn't care which happened.
  List<LyricLineSegments> get _sections {
    if (lyrics.isNotEmpty) return groupSegmentsByLyricLine(segments, lyrics);
    return groupSingingSegmentsIntoPhrases(segments)
        .map((p) => LyricLineSegments(lineText: '', segments: p))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final sections = _sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppColors.primaryCyan, size: 16),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Pitch Timeline',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Legend stays visible above the timeline, and wraps instead of
        // overflowing once the screen is narrow enough that four entries
        // no longer fit on one line.
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _legendDot('✓', _inTuneColor, 'In Tune'),
            _legendDot('↑', _sharpColor, 'Sharp'),
            _legendDot('↓', _flatColor, 'Flat'),
            _legendDot('--', _noSignalColor, 'No Pitch'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a note for details',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LyricLineCard(section: sections[i]),
        ],
      ],
    );
  }

  Widget _legendDot(String glyph, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          glyph,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

/// One lyric line of the song: its start time and reference text, over the
/// words actually sung during it. Each word appears exactly once, however
/// many ground-truth syllables or CREPE frames it spans — see [_WordBlock].
class _LyricLineCard extends StatelessWidget {
  final LyricLineSegments section;
  const _LyricLineCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final wordGroups = groupSegmentsByRecognizedWord(section.segments);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatClockTime(section.startTimeMs),
                style: const TextStyle(
                  color: AppColors.primaryCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.3,
                ),
              ),
              if (section.lineText.isNotEmpty) ...[
                const SizedBox(width: 8),
                // The reference lyric line for this section — what the song
                // says here, as context for the words below it.
                Expanded(
                  child: Text(
                    section.lineText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: wordGroups.map((g) => _WordBlock(segments: g)).toList(),
          ),
        ],
      ),
    );
  }
}

/// One recognized word OCCURRENCE — shown once, like a lyric — with a
/// small chip per ground-truth syllable it was sung across, each
/// independently tappable for that syllable's full pitch detail.
///
/// This is what keeps a word that spans several syllables, several
/// ground-truth notes, or a whole run of CREPE frames (vibrato, a slide)
/// from repeating itself down the timeline: the pitch movement is shown
/// INSIDE the one lyric, as "A3 ✓ → B3 ↓", rather than as the same word
/// printed once per measurement. A word only appears twice when the singer
/// actually sang it twice — see [groupSegmentsByRecognizedWord].
class _WordBlock extends StatelessWidget {
  final List<SingingSegment> segments;
  const _WordBlock({required this.segments});

  String get _timeLabel =>
      '${(segments.first.startTimeMs / 1000).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    final word = segments.first.actualWord;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _timeLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              // An arrow between chips reads as pitch MOVEMENT within this
              // one lyric, which is exactly what it is.
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '→',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                ),
              _SyllableChip(segment: segments[i]),
            ],
          ],
        ),
        const SizedBox(height: 3),
        // What Whisper actually heard the user sing here — not the
        // reference syllable (that's in the detail sheet as "Expected").
        Text(
          word ?? '…',
          style: TextStyle(
            color: word != null ? Colors.white : Colors.white.withValues(alpha: 0.3),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
            fontStyle: word != null ? FontStyle.normal : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// One ground-truth syllable's target note (tiny, muted) over its actual
/// note + compact status glyph (colored chip) — the "IN TUNE"/"SHARP"/
/// "FLAT" words themselves live in the detail sheet opened on tap, not
/// here, so a word with several syllables still reads compactly.
class _SyllableChip extends StatelessWidget {
  final SingingSegment segment;
  const _SyllableChip({required this.segment});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(segment.status);
    final hasPitch = segment.actualNote != null;

    return GestureDetector(
      onTap: () => showSingingSegmentDetail(context, segment),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            segment.targetNote,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 9,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  segment.actualNote ?? '--',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                if (hasPitch) ...[
                  const SizedBox(width: 2),
                  Text(
                    _glyphFor(segment.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
