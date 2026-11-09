import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/core/widgets/app_panel.dart';
import 'package:codegraph/core/widgets/section_label.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';
import 'package:codegraph/features/settings/ai_settings.dart';
import 'package:codegraph/features/settings/settings_controller.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _modelController;
  late double _timeoutSeconds;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _urlController = TextEditingController(text: settings.baseUrl);
    _modelController = TextEditingController(text: settings.model);
    _timeoutSeconds = settings.timeout.inSeconds.toDouble();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  AiSettings _draft() {
    return AiSettings(
      baseUrl: _urlController.text.trim(),
      model: _modelController.text.trim(),
      timeout: Duration(seconds: _timeoutSeconds.round()),
    );
  }

  String? _validate() {
    final url = _draft().normalizedBaseUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return 'Укажите корректный адрес, например http://localhost:11434';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Поддерживаются только http/https.';
    }
    if (_modelController.text.trim().isEmpty) {
      return 'Укажите имя модели, например qwen2.5-coder.';
    }
    return null;
  }

  Future<void> _save(BuildContext context) async {
    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final settings = context.read<SettingsController>();
    final inspector = context.read<InspectorController>();

    setState(() => _validationError = null);
    await settings.save(_draft());
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Настройки локального ИИ сохранены.')),
    );
    await inspector.refreshStatus();
  }

  Future<void> _test() async {
    final error = _validate();
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    setState(() => _validationError = null);
    final settings = context.read<SettingsController>();
    final inspector = context.read<InspectorController>();
    await settings.save(_draft());
    if (!mounted) return;
    await inspector.refreshStatus();
  }

  void _resetToDefaults() {
    setState(() {
      _urlController.text = AiSettings.defaults.baseUrl;
      _modelController.text = AiSettings.defaults.model;
      _timeoutSeconds = AiSettings.defaults.timeout.inSeconds.toDouble();
      _validationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final inspector = context.watch<InspectorController>();
    final settings = context.watch<SettingsController>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: AppPanel(
          padding: const EdgeInsets.all(24),
          borderColor: AppColors.borderStrong,
          radius: 20,
          gradient: AppColors.panelGradient,
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, blurRadius: 48, spreadRadius: 8),
          ],
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Локальный ИИ-инспектор',
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ollama работает на этом компьютере. Код проекта '
                            'не покидает устройство.',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel(title: 'Подключение'),
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Адрес Ollama',
                    hintText: 'http://localhost:11434',
                    prefixIcon: Icon(Icons.link_rounded, size: 17),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Модель',
                    hintText: 'qwen2.5-coder',
                    prefixIcon: Icon(Icons.memory_rounded, size: 17),
                  ),
                ),
                if (inspector.status?.availableModels.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text('Доступные модели:', style: textTheme.labelSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final model
                          in inspector.status!.availableModels.take(8))
                        _ModelChip(
                          model: model,
                          selected: model == _modelController.text,
                          onTap: () => setState(() {
                            _modelController.text = model;
                          }),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Таймаут ответа', style: textTheme.titleSmall),
                    const Spacer(),
                    MiniBadge(
                      label: '${_timeoutSeconds.round()} с',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                Slider(
                  value: _timeoutSeconds,
                  min: 10,
                  max: 120,
                  divisions: 22,
                  label: '${_timeoutSeconds.round()} с',
                  onChanged: (value) => setState(() => _timeoutSeconds = value),
                ),
                Text(
                  'Для небольших моделей достаточно 30–45 с. На слабом CPU '
                  'увеличьте значение.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                _ConnectionStatus(controller: inspector),
                if (_validationError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerWash,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('Сбросить'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: inspector.connection == AiConnection.checking
                          ? null
                          : _test,
                      icon: inspector.connection == AiConnection.checking
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                              ),
                            )
                          : const Icon(Icons.wifi_tethering_rounded, size: 16),
                      label: const Text('Проверить'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: settings.isSaving
                          ? null
                          : () => _save(context),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  final String model;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? AppColors.primaryDim : AppColors.border,
          ),
        ),
        child: Text(
          model,
          style: TextStyle(
            fontSize: 10.5,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.controller});

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (color, label, detail) = switch (controller.connection) {
      AiConnection.checking => (
        AppColors.warning,
        'Проверяем подключение…',
        'Запрос к /api/tags',
      ),
      AiConnection.online => (
        AppColors.success,
        'Ollama доступна',
        controller.status == null
            ? ''
            : 'Модель: ${controller.status!.model} · '
                  '${controller.status!.availableModels.length} моделей · '
                  '${controller.status!.latency.inMilliseconds} мс',
      ),
      AiConnection.offline => (
        AppColors.danger,
        'Ollama недоступна',
        controller.statusFailure?.message ??
            'Приложение продолжит работу в офлайн-режиме.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusDot(color: color, glow: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(color: color),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
