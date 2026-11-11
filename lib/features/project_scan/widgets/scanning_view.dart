import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/dot_grid_background.dart';
import 'package:flutter/material.dart';

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
              // Вместо градиента — сплошной цвет с прозрачностью
              color: AppColors.bothEdge.withValues(alpha: 0.08),
              borderColor: AppColors.bothEdge,
              radius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 22),
                  Text(
                    'Сканируем проект',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.bothEdge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    path == null
                        ? 'Читаем структуру каталогов…'
                        : Formatters.relativePath(path!),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.bothEdge.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: AppColors.bothEdge,
                      backgroundColor: AppColors.bothEdge.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _ScanStep(
                    text: 'Обходим .dart-файлы и читаем директивы import/export',
                  ),
                  const SizedBox(height: 10),
                  const _ScanStep(
                    text: 'Сопоставляем пути и строим направленный граф',
                  ),
                  const SizedBox(height: 10),
                  const _ScanStep(
                    text: 'Ищем циклы, мёртвый код и нарушения слоёв',
                  ),
                  if (onCancel != null) ...[
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.bothEdge,
                      ),
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
  const _ScanStep({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Убрали иконку, оставили только текст
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.bothEdge.withValues(alpha: 0.8),
                ),
          ),
        ),
      ],
    );
  }
}