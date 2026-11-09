import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';

/// Кнопка-язычок на левой границе инспектора.
///
/// Половина кнопки лежит на панели, половина — на графе, поэтому её удобно
/// нажимать, не целясь в тонкую полосу заголовка.
class InspectorCollapseTab extends StatelessWidget {
  const InspectorCollapseTab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 26,
              height: 52,
              decoration: BoxDecoration(
                color: hovered ? AppColors.surfaceHigh : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hovered
                      ? AppColors.primary.withValues(alpha: 0.55)
                      : AppColors.borderStrong,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 18,
                color: hovered ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
