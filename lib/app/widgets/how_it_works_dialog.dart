import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/section_label.dart';

class HowItWorksDialog extends StatelessWidget {
  const HowItWorksDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const HowItWorksDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          borderColor: AppColors.borderStrong,
          radius: 20,
          gradient: AppColors.panelGradient,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MiniBadge(
                    label: 'Как это работает',
                    color: AppColors.primary,
                    icon: Icons.auto_awesome_outlined,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'От папки до архитектурного вердикта',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'CodeGraph не отправляет код в облако. Сканирование, граф и '
                'детерминированные проверки выполняются локально.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              const _Step(
                index: 1,
                icon: Icons.folder_open_outlined,
                title: 'Сканирование',
                text:
                    'Приложение рекурсивно обходит lib/, извлекает import/export '
                    'и сопоставляет пути с файлами проекта.',
              ),
              const _Step(
                index: 2,
                icon: Icons.hub_outlined,
                title: 'Граф зависимостей',
                text:
                    'Файлы становятся узлами, импорты — направленными рёбрами. '
                    'Слои определяются по структуре папок.',
              ),
              const _Step(
                index: 3,
                icon: Icons.troubleshoot_outlined,
                title: 'Аномалии',
                text:
                    'Алгоритм Тарьяна находит циклы, матрица слоёв — обратные '
                    'зависимости, степень вершин — мёртвый код.',
              ),
              const _Step(
                index: 4,
                icon: Icons.psychology_outlined,
                title: 'Локальный ИИ',
                text:
                    'Ollama получает только описание связей и аномалий. '
                    'Без неё работает офлайн-эвристика.',
                isLast: true,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Исходный код не передаётся в модель: в промпт попадают '
                        'только пути, слои, связи и результаты проверок.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Понятно'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.text,
    this.isLast = false,
  });

  final int index;
  final IconData icon;
  final String title;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '0$index',
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(title, style: textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
