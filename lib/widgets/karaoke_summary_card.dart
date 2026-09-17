import 'package:flutter/material.dart';
import '../models/singing_segment.dart';

/// Compact performance summary at the top of the karaoke result screen —
/// overall in-tune percentage plus a small in-tune/sharp/flat breakdown.
/// Every number comes from [SingingPerformanceSummary], itself computed
/// from the actual analyzed [SingingSegment]s — nothing here is hardcoded,
/// and silence/no-pitch segments never count toward these percentages.
/// Renders nothing if there's no ground-truth data for this song.
class KaraokeSummaryCard extends StatelessWidget {
  final SingingPerformanceSummary summary;
  const KaraokeSummaryCard({super.key, required this.summary});

  static const _inTuneColor = Color(0xFF4CAF50);
  static const _sharpColor = Color(0xFFFF5252);
  static const _flatColor = Color(0xFF448AFF);

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            'PITCH ACCURACY',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.inTunePercent.round()}%',
            style: const TextStyle(
              color: _inTuneColor,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              fontFamily: 'Roboto',
              height: 1.1,
            ),
          ),
          const Text(
            'IN TUNE',
            style: TextStyle(
              color: _inTuneColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Roboto',
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('✓', summary.inTunePercent, _inTuneColor),
              _stat('↑', summary.sharpPercent, _sharpColor),
              _stat('↓', summary.flatPercent, _flatColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Based on ${summary.validSegments} of ${summary.totalSegments} '
            'syllables in this recording (${summary.coveragePercent.round()}% covered)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String glyph, double percent, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          glyph,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${percent.round()}%',
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}
