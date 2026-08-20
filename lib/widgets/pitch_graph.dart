/// Real-time scrolling pitch graph — cents deviation from the target note
/// over the last few seconds, with a shaded "in tune" band down the
/// middle. Readings above the band are sharp, below are flat.
library;

import 'package:flutter/material.dart';

class PitchGraph extends StatelessWidget {
  /// Most recent cents-deviation readings, oldest first. Use `null` for a
  /// no-signal frame (not silence-as-zero) so gaps render as gaps.
  final List<double?> centsHistory;
  final double toleranceCents;
  final double height;

  const PitchGraph({
    super.key,
    required this.centsHistory,
    this.toleranceCents = 25.0,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PitchGraphPainter(
          history: centsHistory,
          toleranceCents: toleranceCents,
        ),
      ),
    );
  }
}

class _PitchGraphPainter extends CustomPainter {
  final List<double?> history;
  final double toleranceCents;
  static const double _range = 60.0; // clamp display to ±60 cents

  _PitchGraphPainter({required this.history, required this.toleranceCents});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    double yFor(double cents) {
      final clamped = cents.clamp(-_range, _range);
      return midY - (clamped / _range) * midY;
    }

    // In-tune band
    final bandTop = yFor(toleranceCents);
    final bandBottom = yFor(-toleranceCents);
    final bandPaint = Paint()..color = const Color(0xFF1DB954).withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTRB(0, bandTop, size.width, bandBottom), bandPaint);

    // Center line
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), centerPaint);

    if (history.isEmpty) return;

    final n = history.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;

    Path? currentPath;
    Color currentColor = Colors.white;

    Color colorFor(double cents) {
      if (cents.abs() <= toleranceCents) return const Color(0xFF1DB954);
      if (cents > 0) return const Color(0xFFFF5252); // sharp
      return const Color(0xFF448AFF); // flat
    }

    void flush() {
      if (currentPath != null) {
        final paint = Paint()
          ..color = currentColor
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(currentPath!, paint);
      }
      currentPath = null;
    }

    for (var i = 0; i < n; i++) {
      final cents = history[i];
      final x = i * stepX;
      if (cents == null) {
        flush();
        continue;
      }
      final y = yFor(cents);
      final color = colorFor(cents);

      if (currentPath == null || color != currentColor) {
        flush();
        currentColor = color;
        currentPath = Path()..moveTo(x, y);
      } else {
        currentPath!.lineTo(x, y);
      }
    }
    flush();

    // Emphasize the most recent point.
    for (var i = n - 1; i >= 0; i--) {
      final cents = history[i];
      if (cents == null) continue;
      final x = i * stepX;
      final y = yFor(cents);
      canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = colorFor(cents));
      break;
    }
  }

  @override
  bool shouldRepaint(covariant _PitchGraphPainter oldDelegate) =>
      oldDelegate.history != history || oldDelegate.toleranceCents != toleranceCents;
}
