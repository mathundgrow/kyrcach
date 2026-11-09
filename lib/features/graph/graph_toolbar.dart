import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/features/graph/graph_controller.dart';

class GraphToolbar extends StatelessWidget {
  const GraphToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GraphController>();
    final displayed = controller.displayedFiles.length;
    final total = controller.graph?.fileCount ?? 0;
    final selected = controller.selectedFile;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.add_rounded,
            tooltip: 'Приблизить',
            onTap: controller.zoomIn,
          ),
          _ToolButton(
            icon: Icons.remove_rounded,
            tooltip: 'Отдалить',
            onTap: controller.zoomOut,
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            color: AppColors.border,
          ),
          _ToolButton(
            icon: Icons.auto_graph_rounded,
            tooltip: 'Перестроить раскладку',
            onTap: controller.recalculateLayout,
          ),
          if (selected != null) ...[
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              color: AppColors.border,
            ),
            _ToolButton(
              icon: Icons.close_rounded,
              tooltip: 'Снять выделение',
              onTap: () => controller.selectNode(null),
            ),
          ],
          Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$displayed / $total',
              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 30,
              height: 28,
              decoration: BoxDecoration(
                color: hovered
                    ? AppColors.primary.withValues(alpha: 0.09)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                size: 15,
                color: hovered ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
