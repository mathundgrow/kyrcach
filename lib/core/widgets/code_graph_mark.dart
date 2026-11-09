import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';

class CodeGraphMark extends StatelessWidget {
  const CodeGraphMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.amberGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final a = Offset(size.width * 0.30, size.height * 0.30);
    final b = Offset(size.width * 0.72, size.height * 0.24);
    final c = Offset(size.width * 0.52, size.height * 0.70);

    canvas.drawLine(a, c, paint);
    canvas.drawLine(b, c, paint);
    canvas.drawLine(a, b, paint);

    final fill = Paint()..color = AppColors.background;
    for (final point in [a, b, c]) {
      canvas.drawCircle(point, size.width * 0.095, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
