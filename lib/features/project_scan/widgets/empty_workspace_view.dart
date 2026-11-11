import 'dart:math' as math;

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/dot_grid_background.dart';
import 'package:flutter/material.dart';

class EmptyWorkspaceView extends StatelessWidget {
  const EmptyWorkspaceView({
    super.key,
    required this.onOpenProject,
    required this.onHowItWorks,
  });

  final VoidCallback onOpenProject;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DotGridBackground(spacing: 34, opacity: 0.05),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.bothEdge.withValues(alpha: 0.01),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final showPreview = constraints.maxWidth >= 1000;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(44, 40, 44, 34),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 74),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: showPreview ? 6 : 10,
                              child: _Hero(
                                onOpenProject: onOpenProject,
                                onHowItWorks: onHowItWorks,
                              ),
                            ),
                            if (showPreview) ...[
                              const SizedBox(width: 48),
                              const Expanded(flex: 5, child: _PreviewImage()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 88),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/images/graph_preview.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onOpenProject, required this.onHowItWorks});

  final VoidCallback onOpenProject;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        RichText(
          text: TextSpan(
            style: textTheme.displayLarge,

            children: [
              const TextSpan(text: 'Локальный ИИ '),
              TextSpan(
                text: 'АНАЛИЗАТОР',
                style: textTheme.displayLarge?.copyWith(
                  color: AppColors.bothEdge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Анализатор строит интерактивный граф Dart-проекта, находит циклы, '
            'мёртвый код и нарушения слоёв\n'
            'А локальный ИИ объясняет, что '
            'исправить — без отправки исходников в облако',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            FilledButton.icon(
              onPressed: onOpenProject,
              icon: const Icon(Icons.folder_open_rounded, size: 17),
              label: const Text('Открыть проект'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onHowItWorks,
              label: const Text(
                'Как это работает?',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
