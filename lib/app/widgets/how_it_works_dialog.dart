import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/section_label.dart';
import 'package:flutter/material.dart';

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
          borderColor: AppColors.bothEdge.withValues(alpha: 0.5),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Center(
                    child: const MiniBadge(
                      label: 'Как это работает?',
                      color: AppColors.bothEdge,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'От папки до архитектурного вердикта',
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const _Step(
                index: 1,
                title: 'Сканирование',
                text:
                    'Приложение рекурсивно обходит lib/, извлекает import/export '
                    'и сопоставляет пути с файлами проекта.',
              ),
              const _Step(
                index: 2,
                title: 'Граф зависимостей',
                text:
                    'Файлы становятся узлами, импорты — направленными рёбрами. '
                    'Слои определяются по структуре папок.',
              ),
              const _Step(
                index: 3,
                title: 'Аномалии',
                text:
                    'Алгоритм Тарьяна находит циклы, матрица слоёв — обратные '
                    'зависимости, степень вершин — мёртвый код.',
              ),
              const _Step(
                index: 4,
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
                  color: AppColors.bothEdge.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.bothEdge,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Исходный код не передаётся в модель: в промпт попадают '
                        'только пути, слои, связи и результаты проверок.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.bothEdge,
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
                  child: const Text('Уяснил'),
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
    required this.title,
    required this.text,
    this.isLast = false,
  });

  final int index;
  final String title;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '0$index',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.bothEdge,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(text, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
