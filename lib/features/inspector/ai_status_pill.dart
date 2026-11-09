import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/core/widgets/section_label.dart';
import 'package:codegraph/features/settings/settings_controller.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';

class AiStatusPill extends StatelessWidget {
  const AiStatusPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inspector = context.watch<InspectorController>();
    final settings = context.watch<SettingsController>().settings;

    final (color, label, detail) = switch (inspector.connection) {
      AiConnection.checking => (AppColors.warning, 'Ollama', 'проверка…'),
      AiConnection.online => (AppColors.success, 'Ollama', settings.model),
      AiConnection.offline => (AppColors.danger, 'Ollama', 'offline'),
    };

    final tooltip = switch (inspector.connection) {
      AiConnection.checking => 'Проверяем локальный сервер Ollama',
      AiConnection.online =>
        'Подключено: ${settings.normalizedBaseUrl}\n'
            'Модель: ${settings.model}\n'
            'Моделей на сервере: ${inspector.status?.availableModels.length ?? 0}\n'
            'Нажмите, чтобы изменить настройки',
      AiConnection.offline =>
        '${inspector.statusFailure?.message ?? 'Ollama недоступна'}\n'
            'Доступен офлайн-режим. Нажмите, чтобы настроить.',
    };

    return Tooltip(
      message: tooltip,
      child: HoverSurface(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        radius: 9,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(color: color, glow: true, size: 6),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            if (inspector.connection == AiConnection.checking) ...[
              const SizedBox(width: 7),
              const SizedBox(
                width: 9,
                height: 9,
                child: CircularProgressIndicator(strokeWidth: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
