import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/core/widgets/app_panel.dart';

import 'package:codegraph/core/widgets/dot_grid_background.dart';

class ScanningView extends StatelessWidget {
  const ScanningView({super.key, required this.path, required this.onCancel});

  final String? path;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        const Positioned.fill(
          child: DotGridBackground(spacing: 32, opacity: 0.05),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppPanel(
              padding: const EdgeInsets.all(32),
              gradient: AppColors.panelGradient,
              borderColor: AppColors.borderStrong,
              radius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 22),
                  Text('Сканируем проект', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    path == null
                        ? 'Читаем структуру каталогов…'
                        : Formatters.relativePath(path!),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                  const SizedBox(height: 22),
                  const _ScanStep(
                    icon: Icons.folder_open_outlined,
                    text:
                        'Обходим .dart-файлы и читаем директивы import/export',
                  ),
                  const SizedBox(height: 10),
                  const _ScanStep(
                    icon: Icons.hub_outlined,
                    text: 'Сопоставляем пути и строим направленный граф',
                  ),
                  const SizedBox(height: 10),
                  const _ScanStep(
                    icon: Icons.troubleshoot_outlined,
                    text: 'Ищем циклы, мёртвый код и нарушения слоёв',
                  ),
                  if (onCancel != null) ...[
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Отменить'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: AppColors.primaryDim),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
