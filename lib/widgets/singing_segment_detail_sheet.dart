import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../core/note_utils.dart' show PitchFeedback, centsFromTarget;
import '../models/singing_segment.dart';

const _inTuneColor = Color(0xFF4CAF50);
const _sharpColor = Color(0xFFFF5252);
const _flatColor = Color(0xFF448AFF);
const _noSignalColor = Color(0xFF757575);

Color _colorFor(PitchFeedback status) {
  switch (status) {
    case PitchFeedback.correct:
      return _inTuneColor;
    case PitchFeedback.tooHigh:
      return _sharpColor;
    case PitchFeedback.tooLow:
      return _flatColor;
    case PitchFeedback.noSignal:
      return _noSignalColor;
  }
}

String _statusLabel(PitchFeedback status) {
  switch (status) {
    case PitchFeedback.correct:
      return 'IN TUNE';
    case PitchFeedback.tooHigh:
      return 'SHARP';
    case PitchFeedback.tooLow:
      return 'FLAT';
    case PitchFeedback.noSignal:
      return 'NO PITCH';
  }
}

String _statusGlyph(PitchFeedback status) {
  switch (status) {
    case PitchFeedback.correct:
      return '✓';
    case PitchFeedback.tooHigh:
      return '↑';
    case PitchFeedback.tooLow:
      return '↓';
    case PitchFeedback.noSignal:
      return '–';
  }
}

String _formatSeconds(int ms) => (ms / 1000).toStringAsFixed(2);

String _formatCents(double cents) {
  final rounded = cents.round();
  final sign = rounded > 0 ? '+' : '';
  return '$sign$rounded cents';
}

/// Opens the Level-2 detail view for one tapped pitch segment — the exact,
/// non-hardcoded target/actual/cents/confidence/time-range numbers behind
/// that segment's compact glyph in the main timeline.
void showSingingSegmentDetail(BuildContext context, SingingSegment segment) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SingingSegmentDetailSheet(segment: segment),
  );
}

class SingingSegmentDetailSheet extends StatelessWidget {
  final SingingSegment segment;
  const SingingSegmentDetailSheet({super.key, required this.segment});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(segment.status);
    final hasPitch = segment.actualNote != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '"${segment.actualWord ?? '(not recognized)'}"',
              style: TextStyle(
                color: segment.actualWord != null
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
                fontStyle: segment.actualWord != null
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(
              'Expected',
              segment.syllable.isEmpty ? '--' : segment.syllable,
            ),
            _detailRow(
              'Target',
              '${segment.targetNote}  ·  '
              '${segment.targetFrequency.toStringAsFixed(2)} Hz',
            ),
            _detailRow(
              'Your pitch',
              hasPitch
                  ? '${segment.actualNote}  ·  '
                      '${segment.actualFrequency!.toStringAsFixed(2)} Hz'
                  : '--',
            ),
            _detailRow(
              'Difference',
              hasPitch ? _formatCents(segment.differenceCents!) : '--',
            ),
            _detailRow(
              'Status',
              '${_statusGlyph(segment.status)} ${_statusLabel(segment.status)}',
              valueColor: color,
            ),
            _detailRow(
              'Confidence',
              hasPitch ? '${(segment.confidence * 100).round()}%' : '--',
            ),
            _detailRow(
              'Time',
              '${_formatSeconds(segment.startTimeMs)}–'
              '${_formatSeconds(segment.endTimeMs)}s',
            ),
            if (segment.frameFrequencies.length > 1) ...[
              const SizedBox(height: 18),
              Text(
                'Pitch movement',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 8),
              _PitchMovementChart(
                frameFrequencies: segment.frameFrequencies,
                targetFrequency: segment.targetFrequency,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small inline chart of how pitch moved, frame by frame, during one
/// syllable — each frame plotted as a dot offset from a center line by its
/// cents deviation from the target (clamped to ±100 cents so one wild
/// outlier can't flatten the rest of the shape), colored the same way the
/// timeline colors segments. Reveals vibrato/slides that the single
/// summarized note necessarily hides.
class _PitchMovementChart extends StatelessWidget {
  final List<double> frameFrequencies;
  final double targetFrequency;
  static const _clampCents = 100.0;

  const _PitchMovementChart({
    required this.frameFrequencies,
    required this.targetFrequency,
  });

  @override
  Widget build(BuildContext context) {
    final cents = frameFrequencies
        .map((f) => centsFromTarget(f, targetFrequency).clamp(-_clampCents, _clampCents))
        .toList();

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: CustomPaint(
        painter: _PitchMovementPainter(cents: cents),
      ),
    );
  }
}

class _PitchMovementPainter extends CustomPainter {
  final List<double> cents;
  const _PitchMovementPainter({required this.cents});

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;

    final centerLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), centerLine);

    if (cents.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double xFor(int i) => cents.length == 1
        ? size.width / 2
        : size.width * i / (cents.length - 1);
    double yFor(double c) => centerY - (c / _PitchMovementChart._clampCents) * (centerY - 6);

    final path = Path();
    for (var i = 0; i < cents.length; i++) {
      final point = Offset(xFor(i), yFor(cents[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < cents.length; i++) {
      final c = cents[i];
      final dotColor = c.abs() <= 25
          ? _inTuneColor
          : (c > 0 ? _sharpColor : _flatColor);
      canvas.drawCircle(
        Offset(xFor(i), yFor(c)),
        2.5,
        Paint()..color = dotColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchMovementPainter oldDelegate) =>
      oldDelegate.cents != cents;
}
