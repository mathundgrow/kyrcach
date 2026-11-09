import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/dot_grid_background.dart';
import 'package:codegraph/core/widgets/section_label.dart';

class ScanErrorView extends StatelessWidget {
  const ScanErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onChooseAnother,
  });

  final AppFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        const Positioned.fill(
          child: DotGridBackground(spacing: 32, opacity: 0.04),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: AppPanel(
              padding: const EdgeInsets.all(28),
              gradient: AppColors.panelGradient,
              borderColor: AppColors.danger.withValues(alpha: 0.35),
              radius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerWash,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.folder_off_outlined,
                          color: AppColors.danger,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Не удалось проанализировать проект',
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(switch (failure.code) {
                              FailureCode.accessDenied =>
                                'Проверьте права доступа к каталогу.',
                              FailureCode.notFound =>
                                'Каталог больше не существует.',
                              _ => 'Сканирование остановлено.',
                            }, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(failure.message, style: textTheme.bodyMedium),
                  if (failure.details != null &&
                      failure.details!.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const SectionLabel(title: 'Детали'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        failure.details!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Повторить'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: onChooseAnother,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Другая папка'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyGraphView extends StatelessWidget {
  const EmptyGraphView({
    super.key,
    required this.onChooseAnother,
    required this.path,
  });

  final VoidCallback onChooseAnother;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: AppPanel(
          padding: const EdgeInsets.all(30),
          gradient: AppColors.panelGradient,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 34,
                color: AppColors.primaryDim,
              ),
              const SizedBox(height: 16),
              Text('Dart-файлы не найдены', style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'В выбранном каталоге нет .dart-файлов. Укажите корень '
                'Flutter-проекта или его папку lib/.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
              if (path != null) ...[
                const SizedBox(height: 10),
                Text(
                  path!,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onChooseAnother,
                icon: const Icon(Icons.folder_open_rounded, size: 16),
                label: const Text('Выбрать другую папку'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
