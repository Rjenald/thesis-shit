import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryCyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final centerY = size.height / 2;

    path.moveTo(0, centerY);

    for (double x = 0; x < size.width; x += 4) {
      final amplitude = 20 + (x % 100) / 5;
      final y =
          centerY +
          (x % 40 < 20 ? -amplitude : amplitude) *
              (0.5 + 0.5 * (x / size.width));
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
