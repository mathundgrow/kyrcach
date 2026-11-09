import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/dot_grid_background.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/core/widgets/section_label.dart';

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
              gradient: RadialGradient(
                center: const Alignment(-0.55, -0.75),
                radius: 1.35,
                colors: [
                  AppColors.primary.withValues(alpha: 0.055),
                  Colors.transparent,
                ],
              ),
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
                              const Expanded(flex: 5, child: _GraphPreview()),
                            ],
                          ],
                        ),
                        const SizedBox(height: 44),
                        const _FeatureRow(),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Dart / Flutter · macOS, Windows, Linux · данные не отправляются в облако',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(fontSize: 9.5),
                            ),
                          ],
                        ),
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
        const MiniBadge(
          label: 'Локальный архитектурный аудит',
          color: AppColors.primary,
          icon: Icons.bolt_rounded,
        ),
        const SizedBox(height: 22),
        RichText(
          text: TextSpan(
            style: textTheme.displayLarge,
            children: [
              const TextSpan(text: 'Увидеть архитектуру\n'),
              TextSpan(
                text: 'целиком',
                style: textTheme.displayLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'CodeGraph строит интерактивный граф Dart-проекта, находит циклы, '
            'мёртвый код и нарушения слоёв. Локальный ИИ объясняет, что '
            'исправить — без отправки исходников в облако.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
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
              icon: const Icon(Icons.play_circle_outline_rounded, size: 17),
              label: const Text('Как это работает'),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 820;
        const cards = [
          (
            Icons.hub_outlined,
            'Интерактивный граф',
            'Узлы-файлы, направленные импорты, зум и фильтры по слоям.',
            AppColors.primary,
          ),
          (
            Icons.troubleshoot_rounded,
            'Поиск аномалий',
            'Циклы, мёртвый код, нарушения слоёв и высокая связанность.',
            AppColors.issueWarning,
          ),
          (
            Icons.psychology_outlined,
            'Локальный ИИ',
            'Ollama объясняет риски и предлагает шаги рефакторинга.',
            AppColors.info,
          ),
        ];

        final widgets = [
          for (final card in cards)
            _FeatureCard(
              icon: card.$1,
              title: card.$2,
              text: card.$3,
              color: card.$4,
            ),
        ];

        if (narrow) {
          return Column(
            children: [
              for (var i = 0; i < widgets.length; i++) ...[
                widgets[i],
                if (i != widgets.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        // IntrinsicHeight даёт Row конечную высоту, иначе stretch внутри
        // прокручиваемой колонки требует бесконечную высоту.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widgets.length; i++) ...[
                Expanded(child: widgets[i]),
                if (i != widgets.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return HoverBuilder(
      builder: (context, hovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hovered ? AppColors.surfaceRaised : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hovered ? AppColors.borderStrong : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: textTheme.labelSmall?.copyWith(
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
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

class _GraphPreview extends StatelessWidget {
  const _GraphPreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.18,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C160B), Color(0xFF0F0C07)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 60,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: CustomPaint(painter: _PreviewPainter()),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              child: Row(
                children: const [
                  MiniBadge(
                    label: 'presentation',
                    color: Color(0xFFF2C14E),
                    dense: true,
                  ),
                  SizedBox(width: 6),
                  MiniBadge(
                    label: 'domain',
                    color: Color(0xFF8DD17E),
                    dense: true,
                  ),
                ],
              ),
            ),
            const Positioned(
              right: 18,
              top: 18,
              child: MiniBadge(
                label: 'data',
                color: Color(0xFF68A7FF),
                dense: true,
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'граф проекта',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  const MiniBadge(
                    label: '2 cycle',
                    color: AppColors.danger,
                    dense: true,
                  ),
                  const SizedBox(width: 5),
                  const MiniBadge(
                    label: '3 dead',
                    color: AppColors.issueWarning,
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  static const _points = [
    Offset(0.16, 0.25),
    Offset(0.46, 0.18),
    Offset(0.78, 0.27),
    Offset(0.25, 0.52),
    Offset(0.58, 0.46),
    Offset(0.84, 0.55),
    Offset(0.38, 0.78),
    Offset(0.68, 0.76),
  ];

  static const _edges = [
    (0, 1, Color(0xFFF2C14E)),
    (1, 2, Color(0xFFF2C14E)),
    (0, 3, Color(0xFFF2C14E)),
    (1, 4, Color(0xFF8DD17E)),
    (3, 4, Color(0xFF8DD17E)),
    (2, 4, Color(0xFF68A7FF)),
    (2, 5, Color(0xFF68A7FF)),
    (4, 6, Color(0xFFB58CFF)),
    (4, 7, Color(0xFF8DD17E)),
    (5, 7, Color(0xFF68A7FF)),
    (6, 7, Color(0xFFFF6B57)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList();

    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    for (final edge in _edges) {
      final from = points[edge.$1];
      final to = points[edge.$2];
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          (from.dx + to.dx) / 2,
          from.dy,
          (from.dx + to.dx) / 2,
          to.dy,
          to.dx,
          to.dy,
        );
      canvas.drawPath(path, glow..color = edge.$3.withValues(alpha: 0.12));
      canvas.drawPath(
        path,
        Paint()
          ..color = edge.$3.withValues(alpha: 0.45)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    final colors = [
      const Color(0xFFF2C14E),
      const Color(0xFFF2C14E),
      const Color(0xFFF2C14E),
      const Color(0xFFF2C14E),
      const Color(0xFF8DD17E),
      const Color(0xFF68A7FF),
      const Color(0xFFB58CFF),
      const Color(0xFFFF6B57),
    ];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final color = colors[i];
      canvas.drawCircle(
        point,
        24,
        Paint()
          ..color = color.withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(point, 13, Paint()..color = const Color(0xFF1B160D));
      canvas.drawCircle(
        point,
        13,
        Paint()
          ..color = color.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(point, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
