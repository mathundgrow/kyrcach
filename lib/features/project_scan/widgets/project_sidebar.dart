import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/issue_palette.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/project_scan/models/architecture_layer.dart';

class ProjectSidebar extends StatefulWidget {
  const ProjectSidebar({super.key, this.width = 292});

  final double width;

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar> {
  bool _layersExpanded = true;
  bool _issuesExpanded = true;

  Color _healthColor(int score) {
    if (score >= 80) return AppColors.success;
    if (score >= 55) return AppColors.issueWarning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GraphController>();
    final graph = controller.graph;
    final analysis = controller.analysis;
    if (graph == null || analysis == null) {
      return SizedBox(width: widget.width);
    }

    final metrics = analysis.metrics;
    final layers = ArchitectureLayer.values
        .where((layer) => (graph.layerCounts[layer] ?? 0) > 0)
        .toList();
    final hasFilters =
        controller.hiddenLayers.isNotEmpty ||
        controller.issuesOnly ||
        controller.soloLayer != null;
    final unresolvedCount = controller.unresolvedIssueCount;
    final health = controller.adjustedHealthScore;
    final orderedIssues = [
      ...controller.unresolvedIssues,
      ...analysis.issues.where((issue) => controller.isIssueResolved(issue.id)),
    ];

    return Container(
      width: widget.width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Файлы',
                  value: '${metrics.fileCount}',
                  icon: Icons.description_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Связи',
                  value: '${metrics.dependencyCount}',
                  icon: Icons.arrow_outward_rounded,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Аномалии',
                  value: '$unresolvedCount',
                  icon: Icons.warning_amber_rounded,
                  color: unresolvedCount == 0
                      ? AppColors.success
                      : AppColors.issueWarning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'Здоровье',
                  value: '$health',
                  suffix: '/100',
                  icon: Icons.shield_outlined,
                  color: _healthColor(health),
                ),
              ),
            ],
          ),
          const _SidebarDivider(),
          _SectionHeader(
            title: 'Слои',
            expanded: _layersExpanded,
            onTap: () => setState(() => _layersExpanded = !_layersExpanded),
            trailing: hasFilters
                ? InkWell(
                    onTap: controller.clearFilters,
                    borderRadius: BorderRadius.circular(5),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'сбросить',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          if (_layersExpanded) ...[
            const SizedBox(height: 6),
            for (final layer in layers)
              _LayerTile(
                layer: layer,
                count: graph.layerCounts[layer] ?? 0,
                visible: controller.isLayerVisible(layer),
                solo: controller.isLayerSolo(layer),
                onSolo: () => controller.toggleSoloLayer(layer),
                onToggleVisibility: () => controller.toggleLayer(layer),
              ),
            const SizedBox(height: 6),
            _IssuesOnlyTile(
              active: controller.issuesOnly,
              count: unresolvedCount,
              onTap: controller.toggleIssuesOnly,
            ),
          ],
          const _SidebarDivider(),
          _SectionHeader(
            title: 'Проблемы',
            expanded: _issuesExpanded,
            onTap: () => setState(() => _issuesExpanded = !_issuesExpanded),
            trailing: Text(
              '$unresolvedCount',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
          if (_issuesExpanded) ...[
            const SizedBox(height: 7),
            if (orderedIssues.isEmpty)
              const _NoIssuesCard()
            else ...[
              for (final issue in orderedIssues.take(40))
                _IssueTile(
                  issue: issue,
                  active: controller.activeIssueId == issue.id,
                  resolved: controller.isIssueResolved(issue.id),
                  onTap: () => controller.selectIssue(issue),
                  onToggleResolved: () =>
                      controller.toggleIssueResolved(issue.id),
                ),
              if (orderedIssues.length > 40)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Показаны первые 40 из ${orderedIssues.length}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Заголовок блока левой панели: клик сворачивает и разворачивает секцию.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.suffix,
  });

  final String label;
  final String value;
  final String? suffix;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 20,
                  height: 1,
                  color: AppColors.textPrimary,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    suffix!,
                    style: textTheme.labelSmall?.copyWith(fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(label, style: textTheme.labelSmall?.copyWith(fontSize: 9.5)),
        ],
      ),
    );
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.layer,
    required this.count,
    required this.visible,
    required this.solo,
    required this.onSolo,
    required this.onToggleVisibility,
  });

  final ArchitectureLayer layer;
  final int count;
  final bool visible;
  final bool solo;
  final VoidCallback onSolo;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onSolo,
      selected: solo,
      accent: layer.color,
      padding: const EdgeInsets.only(left: 7, top: 7, bottom: 7, right: 3),
      radius: 8,
      tooltip: solo ? 'Показать все слои' : 'Показать только этот слой',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0.4,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: layer.color,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                layer.title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: solo ? FontWeight.w600 : FontWeight.w400,
                  color: solo ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const SizedBox(width: 2),
            Tooltip(
              message: visible ? 'Скрыть слой' : 'Показать слой',
              child: GestureDetector(
                onTap: onToggleVisibility,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 13,
                    color: visible ? AppColors.textMuted : AppColors.danger,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssuesOnlyTile extends StatelessWidget {
  const _IssuesOnlyTile({
    required this.active,
    required this.count,
    required this.onTap,
  });

  final bool active;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onTap,
      selected: active,
      accent: AppColors.issueWarning,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      radius: 8,
      tooltip: 'Показывать только файлы с аномалиями',
      child: Row(
        children: [
          Icon(
            active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
            size: 13,
            color: active ? AppColors.issueWarning : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Только проблемные',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              color: active ? AppColors.issueWarning : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.issue,
    required this.active,
    required this.resolved,
    required this.onTap,
    required this.onToggleResolved,
  });

  final ArchitectureIssue issue;
  final bool active;
  final bool resolved;
  final VoidCallback onTap;
  final VoidCallback onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.textMuted : issue.severity.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: HoverSurface(
        onTap: onTap,
        selected: active,
        accent: color,
        padding: const EdgeInsets.fromLTRB(9, 7, 4, 7),
        radius: 9,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                resolved ? Icons.check_circle_outline_rounded : issue.kind.icon,
                size: 13,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: resolved
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            decoration: resolved
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resolved ? 'проверено' : issue.kind.shortLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: resolved
                  ? 'Снова считать аномалией'
                  : 'Отметить как проверенное',
              child: GestureDetector(
                onTap: onToggleResolved,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    resolved
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: resolved ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoIssuesCard extends StatelessWidget {
  const _NoIssuesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 15,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Структурных аномалий не найдено. Граф выглядит здоровым.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
