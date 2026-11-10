import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/dot_grid_background.dart';
import 'package:codegraph/features/project_scan/models/architecture_layer.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/graph/layered_layout.dart';
import 'graph_node_card.dart';
import 'graph_toolbar.dart';

/// Порядок колонок слева направо: от интерфейса к данным и общему ядру.
const Map<ArchitectureLayer, int> _layerColumns = {
  ArchitectureLayer.presentation: 0,
  ArchitectureLayer.application: 1,
  ArchitectureLayer.domain: 2,
  ArchitectureLayer.data: 3,
  ArchitectureLayer.core: 4,
  ArchitectureLayer.unknown: 5,
};

class GraphCanvas extends StatelessWidget {
  const GraphCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.canvasGradient),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DotGridBackground(spacing: 30, opacity: 0.055),
          ),
          Positioned.fill(
            child: Selector<GraphController, String>(
              selector: (_, controller) => controller.structureSignature,
              builder: (context, signature, _) =>
                  _GraphStage(key: ValueKey(signature)),
            ),
          ),
          const Positioned(top: 14, left: 14, child: GraphToolbar()),
          const Positioned(top: 62, left: 14, child: _FocusBanner()),
          const Positioned(bottom: 14, left: 16, child: _CanvasHint()),
          const Positioned(bottom: 14, right: 16, child: _GraphLegend()),
        ],
      ),
    );
  }
}

class _GraphStage extends StatefulWidget {
  const _GraphStage({super.key});

  @override
  State<_GraphStage> createState() => _GraphStageState();
}

class _GraphStageState extends State<_GraphStage> {
  bool _didFit = false;

  @override
  void initState() {
    super.initState();
    // Новая сцена (проект или фильтры) начинается с чистого вида.
    context.read<GraphController>().resetScene();
  }

  @override
  Widget build(BuildContext context) {
    // Слушаем контроллер: выбор узла меняет набор карточек и цвета рёбер,
    // но не пересоздаёт сцену — раскладка строится по `visibleFiles` и остаётся
    // стабильной, поэтому позиции узлов не прыгают.
    final controller = context.watch<GraphController>();
    final graph = controller.graph;
    final analysis = controller.analysis;
    if (graph == null || analysis == null) return const SizedBox.shrink();

    final visible = controller.visibleFiles;
    if (visible.isEmpty) {
      return _FilteredEmptyState(onReset: controller.clearFilters);
    }

    final displayed = controller.displayedFiles;

    final layout = computeLayeredLayout(
      nodeIds: visible.map((file) => file.id),
      columnByNodeId: {
        for (final file in visible)
          file.id: _layerColumns[file.layer] ?? _layerColumns.length,
      },
    );

    final edges = <_SceneEdge>[];
    for (final edge in controller.displayedEdges) {
      final from = layout.centerOf(edge.fromId);
      final to = layout.centerOf(edge.toId);
      if (from == null || to == null) continue;

      final sourceFile = graph.fileById(edge.fromId);
      if (sourceFile == null) continue;

      final relation = controller.edgeRelation(edge);
      final isCycle = controller.unresolvedCycleEdgeIds.contains(edge.id);
      final isViolation = controller.unresolvedViolationEdgeIds.contains(
        edge.id,
      );

      // В фокусе цвет ребра показывает направление связи с выбранным файлом,
      // в обычном режиме — слой источника и аномалии.
      final color = switch (relation) {
        GraphRelation.imports => AppColors.importEdge,
        GraphRelation.importer => AppColors.usedByEdge,
        GraphRelation.both => AppColors.bothEdge,
        null when isCycle => AppColors.danger.withValues(alpha: 0.85),
        null when isViolation => AppColors.issueWarning.withValues(alpha: 0.8),
        null => sourceFile.layer.color.withValues(alpha: 0.32),
      };
      final width = relation != null
          ? 2.0
          : isCycle
          ? 1.8
          : (isViolation ? 1.4 : 0.9);

      edges.add(_SceneEdge(from: from, to: to, color: color, width: width));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        controller.updateViewport(constraints.biggest);
        controller.updateScene(layout.size, layout.positions);

        if (!_didFit) {
          _didFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.zoomToFit();
          });
        }

        return InteractiveViewer(
          transformationController: controller.transformationController,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          minScale: 0.05,
          maxScale: 4,
          constrained: false,
          child: SizedBox(
            width: layout.size.width,
            height: layout.size.height,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => controller.selectNode(null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _EdgePainter(edges)),
                  ),
                  for (final file in displayed)
                    Positioned(
                      left: layout.positions[file.id]!.dx,
                      top: layout.positions[file.id]!.dy,
                      width: kNodeWidth,
                      height: kNodeHeight,
                      child: GraphNodeCard(
                        file: file,
                        issues: controller.unresolvedIssuesForNode(file.id),
                        incomingCount: graph.incomingCount(file.id),
                        outgoingCount: graph.outgoingCount(file.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SceneEdge {
  const _SceneEdge({
    required this.from,
    required this.to,
    required this.color,
    required this.width,
  });

  final Offset from;
  final Offset to;
  final Color color;
  final double width;
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.edges);

  final List<_SceneEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in edges) {
      paint
        ..color = edge.color
        ..strokeWidth = edge.width;
      canvas.drawLine(edge.from, edge.to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.edges != edges;
}

/// Плашка режима фокуса: что выбрано и сколько у него связей.
class _FocusBanner extends StatelessWidget {
  const _FocusBanner();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GraphController>();
    final file = controller.selectedFile;
    if (file == null) return const SizedBox.shrink();

    final imports = controller.selectedDependencies.length;
    final usedBy = controller.selectedDependents.length;

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.center_focus_strong_rounded,
            size: 13,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Фокус: ${file.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FocusCount(
            value: imports,
            color: AppColors.importEdge,
            icon: Icons.arrow_outward_rounded,
            tooltip: 'Файл импортирует',
          ),
          const SizedBox(width: 8),
          _FocusCount(
            value: usedBy,
            color: AppColors.usedByEdge,
            icon: Icons.call_received_rounded,
            tooltip: 'Файлы используют этот файл',
          ),
        ],
      ),
    );
  }
}

class _FocusCount extends StatelessWidget {
  const _FocusCount({
    required this.value,
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  final int value;
  final Color color;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasHint extends StatelessWidget {
  const _CanvasHint();

  @override
  Widget build(BuildContext context) {
    final focus = context.select<GraphController, bool>(
      (controller) => controller.isFocusMode,
    );
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          focus
              ? 'клик по фону — вернуть весь граф · колесо — масштаб'
              : 'колесо — масштаб · перетаскивание — панорама · клик по узлу — фокус',
          style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _GraphLegend extends StatelessWidget {
  const _GraphLegend();

  @override
  Widget build(BuildContext context) {
    final focus = context.select<GraphController, bool>(
      (controller) => controller.isFocusMode,
    );
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (focus) ...[
              const _LegendLine(
                color: AppColors.importEdge,
                label: '→ импортирует',
              ),
              const SizedBox(width: 9),
              const _LegendLine(
                color: AppColors.usedByEdge,
                label: '← используют',
              ),
              const SizedBox(width: 9),
            ] else ...[
              const _LegendLine(color: AppColors.textMuted, label: 'слой'),
              const SizedBox(width: 9),
              const _LegendLine(color: AppColors.danger, label: 'цикл'),
              const SizedBox(width: 9),
              const _LegendLine(color: AppColors.issueWarning, label: 'слои'),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 1.6, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 8.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPanel(
        padding: const EdgeInsets.all(22),
        gradient: AppColors.panelGradient,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_alt_off_rounded,
              size: 28,
              color: AppColors.primaryDim,
            ),
            const SizedBox(height: 10),
            Text(
              'Все узлы скрыты фильтрами',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Показать всё'),
            ),
          ],
        ),
      ),
    );
  }
}
