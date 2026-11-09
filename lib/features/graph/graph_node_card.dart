import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/project_scan/source_file.dart';
import 'package:codegraph/features/graph/graph_controller.dart';

class GraphNodeCard extends StatefulWidget {
  const GraphNodeCard({
    super.key,
    required this.file,
    required this.issues,
    required this.incomingCount,
    required this.outgoingCount,
  });

  final SourceFile file;
  final List<ArchitectureIssue> issues;
  final int incomingCount;
  final int outgoingCount;

  @override
  State<GraphNodeCard> createState() => _GraphNodeCardState();
}

class _GraphNodeCardState extends State<GraphNodeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GraphController>();
    final selected = controller.isSelected(widget.file.id);
    final relation = controller.relationTo(widget.file.id);
    final relationColor = switch (relation) {
      GraphRelation.imports => AppColors.importEdge,
      GraphRelation.importer => AppColors.usedByEdge,
      GraphRelation.both => AppColors.bothEdge,
      null => null,
    };

    final hasCritical = widget.issues.any(
      (issue) => issue.severity == IssueSeverity.critical,
    );
    final hasWarning = widget.issues.isNotEmpty;
    final issueColor = hasCritical
        ? AppColors.danger
        : hasWarning
        ? AppColors.issueWarning
        : null;

    final layerColor = widget.file.layer.color;
    final borderColor = selected
        ? AppColors.primary
        : relationColor ?? issueColor ?? AppColors.border;
    final borderWidth = selected ? 2.0 : (relationColor != null ? 1.6 : 1.0);
    final stripeColor = relationColor ?? layerColor;
    final relationLabel = switch (relation) {
      GraphRelation.imports => '→ импорт',
      GraphRelation.importer => '← использует',
      GraphRelation.both => '⇄ оба',
      null => widget.file.layer.shortLabel,
    };
    final relationLabelColor =
        relationColor ?? layerColor.withValues(alpha: 0.9);

    final tooltip = [
      widget.file.relativePath,
      'Слой: ${widget.file.layer.title}',
      'Импорты: ${widget.outgoingCount} · Зависимые: ${widget.incomingCount}',
      if (relation != null)
        switch (relation) {
          GraphRelation.imports => 'Выбранный файл импортирует этот файл',
          GraphRelation.importer => 'Этот файл импортирует выбранный',
          GraphRelation.both => 'Взаимная зависимость с выбранным файлом',
        },
      if (hasWarning)
        'Проблемы: ${widget.issues.map((issue) => issue.kind.shortLabel).toSet().join(', ')}',
    ].join('\n');

    final card = AnimatedScale(
      scale: _hovered ? 1.025 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 224,
        height: 82,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241D11), Color(0xFF18130B)],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                spreadRadius: 1,
              )
            else if (relationColor != null)
              BoxShadow(
                color: relationColor.withValues(alpha: 0.22),
                blurRadius: 18,
              )
            else if (issueColor != null)
              BoxShadow(
                color: issueColor.withValues(alpha: 0.18),
                blurRadius: 16,
              )
            else if (_hovered)
              const BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(width: 3.5, color: stripeColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: layerColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(
                              widget.file.layer.icon,
                              size: 14,
                              color: layerColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (hasWarning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: issueColor!.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasCritical
                                        ? Icons.error_outline_rounded
                                        : Icons.warning_amber_rounded,
                                    size: 9,
                                    color: issueColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${widget.issues.length}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: issueColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        Formatters.shortPath(
                          widget.file.relativePath,
                          maxSegments: 2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _DepCount(
                            icon: Icons.arrow_outward_rounded,
                            value: widget.outgoingCount,
                            color: relation == GraphRelation.imports
                                ? AppColors.importEdge
                                : layerColor,
                          ),
                          const SizedBox(width: 8),
                          _DepCount(
                            icon: Icons.call_received_rounded,
                            value: widget.incomingCount,
                            color: relation == GraphRelation.importer
                                ? AppColors.usedByEdge
                                : AppColors.textMuted,
                          ),
                          const Spacer(),
                          Text(
                            relationLabel,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: relationLabelColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => controller.selectNode(widget.file.id),
          // Панорамирование обрабатывает `InteractiveViewer`: если карточка
          // тоже начнёт двигать сцену, два распознавателя будут перезаписывать
          // матрицу друг друга, и граф задёргается.
          child: card,
        ),
      ),
    );
  }
}

class _DepCount extends StatelessWidget {
  const _DepCount({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 9, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
