import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/core/widgets/code_graph_mark.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/features/inspector/ai_status_pill.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/search/search_box.dart';

/// Верхняя панель: выбранный проект слева, поиск по центру,
/// название приложения с логотипом справа.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onOpenProject,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenProject;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final graph = workspace.graph;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1280;
        final searchWidth = constraints.maxWidth > 1500
            ? 380.0
            : constraints.maxWidth > 1280
            ? 340.0
            : 280.0;

        return Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.surfaceAlt, AppColors.surface],
            ),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Stack(
            children: [
              // Слева — карточка выбранного проекта.
              if (graph != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ProjectChip(
                    graph: graph,
                    compact: compact,
                    onTap: onOpenProject,
                  ),
                ),
              // Поиск — ровно по центру окна.
              if (graph != null) Center(child: SearchBox(width: searchWidth)),
              // Справа — статус ИИ, настройки и название приложения.
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AiStatusPill(onTap: onOpenSettings),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      tooltip: 'Настройки ИИ',
                    ),
                    const SizedBox(width: 10),
                    Container(width: 1, height: 30, color: AppColors.border),
                    const SizedBox(width: 14),
                    Text(
                      'CodeGraph',
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const CodeGraphMark(size: 34),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.graph,
    required this.compact,
    required this.onTap,
  });

  final ProjectGraph graph;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return HoverSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      radius: 9,
      tooltip: 'Сменить проект',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 16,
            color: AppColors.primaryDim,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  graph.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                if (!compact)
                  Text(
                    Formatters.shortPath(graph.rootPath, maxSegments: 2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
