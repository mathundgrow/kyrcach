import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';

class DotGridBackground extends StatelessWidget {
  const DotGridBackground({
    super.key,
    this.spacing = 28,
    this.opacity = 0.07,
    this.child,
  });

  final double spacing;
  final double opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(spacing: spacing, opacity: opacity),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.spacing, required this.opacity});

  final double spacing;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing || oldDelegate.opacity != opacity;
}
