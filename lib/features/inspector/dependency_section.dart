import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/core/widgets/section_label.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/project_scan/source_file.dart';

/// Список зависимостей файла: направление задаёт акцентный цвет.
///
/// Показываем первые [_previewCount] строк, остальные раскрываются в плашке
/// с полным списком — так инспектор не растягивается на весь экран.
class DependencySection extends StatelessWidget {
  const DependencySection({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.files,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<SourceFile> files;
  final String emptyText;

  static const int _previewCount = 6;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hidden = files.length - _previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: title,
          leading: Icon(icon, size: 12, color: accent),
          trailing: MiniBadge(
            label: '${files.length}',
            color: accent,
            dense: true,
          ),
        ),
        const SizedBox(height: 6),
        if (files.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              emptyText,
              style: textTheme.labelSmall?.copyWith(fontSize: 9.5),
            ),
          )
        else ...[
          for (final file in files.take(_previewCount))
            DependencyRow(file: file, accent: accent),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: HoverSurface(
                onTap: () => _showAll(context),
                accent: accent,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                radius: 6,
                tooltip: 'Показать весь список',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'и ещё $hidden',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.unfold_more_rounded, size: 11, color: accent),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _showAll(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.background.withValues(alpha: 0.72),
      builder: (dialogContext) => _DependencyListDialog(
        title: title,
        icon: icon,
        accent: accent,
        files: files,
        onSelect: (file) {
          Navigator.of(dialogContext).pop();
          context.read<GraphController>().selectNode(file.id);
        },
      ),
    );
  }
}

/// Плашка с полным списком зависимостей выбранного файла.
class _DependencyListDialog extends StatelessWidget {
  const _DependencyListDialog({
    required this.title,
    required this.icon,
    required this.accent,
    required this.files,
    required this.onSelect,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<SourceFile> files;
  final ValueChanged<SourceFile> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: AppPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          gradient: AppColors.panelGradient,
          borderColor: accent.withValues(alpha: 0.35),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$title · ${files.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Закрыть',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return DependencyRow(
                        file: file,
                        accent: accent,
                        onTap: () => onSelect(file),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DependencyRow extends StatelessWidget {
  const DependencyRow({
    super.key,
    required this.file,
    required this.accent,
    this.onTap,
  });

  final SourceFile file;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: HoverSurface(
        onTap:
            onTap ?? () => context.read<GraphController>().selectNode(file.id),
        accent: accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        radius: 8,
        tooltip: file.relativePath,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              file.layer.shortLabel,
              style: TextStyle(
                fontSize: 8.5,
                color: file.layer.color.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 13,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
