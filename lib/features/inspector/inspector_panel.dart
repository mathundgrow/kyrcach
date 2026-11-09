import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/app/theme/layer_palette.dart';
import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/core/utils/formatters.dart';
import 'package:codegraph/core/widgets/hover_builder.dart';
import 'package:codegraph/core/widgets/section_label.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/analysis/issue_palette.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/source_file.dart';
import 'package:codegraph/features/settings/ai_settings.dart';
import 'package:codegraph/features/settings/settings_controller.dart';
import 'package:codegraph/features/inspector/ai_diagnosis.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';
import 'dependency_section.dart';

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    this.width = 384,
    required this.onOpenSettings,
  });

  final double width;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final graphController = context.watch<GraphController>();
    final file = graphController.selectedFile;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        // По умолчанию AnimatedSwitcher центрирует ребёнка по вертикали —
        // из-за этого над названием файла появлялся большой пустой отступ.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        child: file == null
            ? const _EmptyInspector(key: ValueKey('empty-inspector'))
            : _FileInspector(
                key: ValueKey(file.id),
                file: file,
                graph: graphController.graph!,
                analysis: graphController.analysis!,
                onOpenSettings: onOpenSettings,
              ),
      ),
    );
  }
}

/// Свёрнутый инспектор: узкая полоса вдоль правой границы.
///
/// Развернуть панель можно плавающим язычком [InspectorCollapseTab] на её
/// левой границе — отдельная кнопка внутри полосы не нужна.
class InspectorRail extends StatelessWidget {
  const InspectorRail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
    );
  }
}

class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 18),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.07),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.ads_click_rounded,
              size: 26,
              color: AppColors.primaryDim,
            ),
          ),
          const SizedBox(height: 18),
          Text('Выберите узел графа', style: textTheme.titleMedium),
          const SizedBox(height: 7),
          Text(
            'Кликните по карточке файла, чтобы увидеть его слой, '
            'входящие и исходящие зависимости и запустить локальную диагностику.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          const _HintRow(
            icon: Icons.touch_app_outlined,
            text: 'Клик по узлу открывает карточку файла',
          ),
          const _HintRow(
            icon: Icons.search_rounded,
            text: 'Поиск находит файл по имени, пути или слою',
          ),
          const _HintRow(
            icon: Icons.filter_alt_outlined,
            text: 'Фильтры слоёв скрывают лишние узлы',
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 11,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'В промпт передаются только связи и аномалии, не исходный код.',
                  style: textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}

class _FileInspector extends StatelessWidget {
  const _FileInspector({
    super.key,
    required this.file,
    required this.graph,
    required this.analysis,
    required this.onOpenSettings,
  });

  final SourceFile file;
  final ProjectGraph graph;
  final GraphAnalysis analysis;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final inspector = context.watch<InspectorController>();
    final graphController = context.watch<GraphController>();
    final settings = context.watch<SettingsController>().settings;
    final issues = analysis.issuesForNode(file.id);
    final unresolved = issues
        .where((issue) => !graphController.isIssueResolved(issue.id))
        .length;
    final report = inspector.reportFor(file.id);
    final error = inspector.errorFor(file.id);
    final loading = inspector.isLoading(file.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileHeader(file: file, graph: graph),
          const SizedBox(height: 16),
          DependencySection(
            title: 'Импортирует',
            icon: Icons.arrow_outward_rounded,
            accent: AppColors.importEdge,
            files: graph.dependenciesOf(file.id),
            emptyText: 'Нет исходящих зависимостей',
          ),
          const SizedBox(height: 14),
          DependencySection(
            title: 'Используют',
            icon: Icons.call_received_rounded,
            accent: AppColors.usedByEdge,
            files: graph.dependentsOf(file.id),
            emptyText: 'Никто не импортирует этот файл',
          ),
          const SizedBox(height: 18),
          SectionLabel(
            title: 'Аномалии',
            leading: const Icon(
              Icons.report_gmailerrorred_rounded,
              size: 12,
              color: AppColors.issueWarning,
            ),
            trailing: Text(
              '$unresolved',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 7),
          if (issues.isEmpty)
            _NoNodeIssues()
          else
            for (final issue in issues)
              _NodeIssueCard(
                issue: issue,
                resolved: graphController.isIssueResolved(issue.id),
                onTap: () => context.read<GraphController>().selectIssue(issue),
                onToggleResolved: () => context
                    .read<GraphController>()
                    .toggleIssueResolved(issue.id),
              ),
          const SizedBox(height: 20),
          const _AiDivider(),
          _AiSection(
            file: file,
            graph: graph,
            settings: settings,
            report: report,
            error: error,
            loading: loading,
            connection: inspector.connection,
            onRun: () => context.read<InspectorController>().inspect(
              graph: graph,
              analysis: analysis,
              file: file,
            ),
            onOpenSettings: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _FileHeader extends StatelessWidget {
  const _FileHeader({required this.file, required this.graph});

  final SourceFile file;
  final ProjectGraph graph;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = file.layer.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(file.layer.icon, size: 19, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Tooltip(
                    message: file.relativePath,
                    child: Text(
                      Formatters.shortPath(file.relativePath, maxSegments: 3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            MiniBadge(
              label: file.layer.title,
              color: color,
              icon: file.layer.icon,
              dense: true,
            ),
            MiniBadge(
              label: '${file.lineCount} строк',
              color: AppColors.textMuted,
              icon: Icons.notes_rounded,
              dense: true,
            ),
            MiniBadge(
              label: '${graph.outgoingCount(file.id)} импортов',
              color: AppColors.importEdge,
              icon: Icons.arrow_outward_rounded,
              dense: true,
            ),
            MiniBadge(
              label: '${graph.incomingCount(file.id)} зависят',
              color: AppColors.usedByEdge,
              icon: Icons.call_received_rounded,
              dense: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _NoNodeIssues extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Для этого файла аномалий не найдено',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeIssueCard extends StatelessWidget {
  const _NodeIssueCard({
    required this.issue,
    required this.resolved,
    required this.onTap,
    required this.onToggleResolved,
  });

  final ArchitectureIssue issue;
  final bool resolved;
  final VoidCallback onTap;
  final VoidCallback onToggleResolved;

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.textMuted : issue.severity.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverSurface(
        onTap: onTap,
        accent: color,
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        radius: 9,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                resolved ? Icons.check_circle_outline_rounded : issue.kind.icon,
                size: 14,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          issue.kind.title,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color,
                            decoration: resolved
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppColors.textMuted,
                          ),
                        ),
                      ),
                      MiniBadge(
                        label: resolved ? 'проверено' : issue.severity.title,
                        color: color,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    issue.description,
                    maxLines: resolved ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      height: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: resolved
                  ? 'Снова считать аномалией'
                  : 'Отметить как проверенное',
              child: GestureDetector(
                onTap: onToggleResolved,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    resolved
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: resolved ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Разделитель, который явно отделяет связи и аномалии от оценки ИИ.
class _AiDivider extends StatelessWidget {
  const _AiDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 5),
                Text(
                  'ОЦЕНКА ИИ',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: AppColors.primaryDim,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.file,
    required this.graph,
    required this.settings,
    required this.report,
    required this.error,
    required this.loading,
    required this.connection,
    required this.onRun,
    required this.onOpenSettings,
  });

  final SourceFile file;
  final ProjectGraph graph;
  final AiSettings settings;
  final AiDiagnosis? report;
  final AppFailure? error;
  final bool loading;
  final AiConnection connection;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF241C0E), Color(0xFF171209)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  'Локальная диагностика',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Tooltip(
                    message: 'Настройки модели',
                    child: GestureDetector(
                      onTap: onOpenSettings,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          settings.model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: loading
                ? _LoadingBlock()
                : report != null
                ? _ReportBlock(
                    report: report!,
                    onRun: onRun,
                    onOpenSettings: onOpenSettings,
                  )
                : error != null
                ? _ErrorBlock(
                    error: error,
                    onRun: onRun,
                    onOpenSettings: onOpenSettings,
                  )
                : _IdleBlock(
                    connection: connection,
                    onRun: onRun,
                    onOpenSettings: onOpenSettings,
                  ),
          ),
        ],
      ),
    );
  }
}

class _IdleBlock extends StatelessWidget {
  const _IdleBlock({
    required this.connection,
    required this.onRun,
    required this.onOpenSettings,
  });

  final AiConnection connection;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final offline = connection == AiConnection.offline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offline
              ? 'Ollama недоступна, но анализ останется рабочим: '
                    'детерминированная эвристика проверит слои, циклы и связи.'
              : 'Модель получит описание слоя, связей и найденных аномалий — '
                    'без исходного кода. Это займёт несколько секунд.',
          style: textTheme.labelSmall?.copyWith(
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (offline) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: onOpenSettings,
            child: const Text(
              'Настроить подключение →',
              style: TextStyle(fontSize: 9.5, color: AppColors.primary),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onRun,
            icon: const Icon(Icons.auto_awesome_rounded, size: 15),
            label: Text(
              offline ? 'Офлайн-диагностика' : 'Запустить диагностику',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11),
              textStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            const SizedBox(width: 9),
            Text(
              'Модель анализирует узел…',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(minHeight: 2.5),
        ),
        const SizedBox(height: 9),
        Text(
          'Формируем контекст связей и ждём ответ Ollama. '
          'Можно продолжать работать с графом.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({
    required this.error,
    required this.onRun,
    required this.onOpenSettings,
  });

  final AppFailure? error;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final message = error?.message ?? 'Неизвестная ошибка';
    final details = error?.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: AppColors.danger,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.danger,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        if (details != null && details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            details,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontSize: 9, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              onPressed: onRun,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
              ),
              child: const Text('Повторить'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Настройки'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportBlock extends StatelessWidget {
  const _ReportBlock({
    required this.report,
    required this.onRun,
    required this.onOpenSettings,
  });

  final AiDiagnosis report;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = switch (report.verdict) {
      DiagnosisVerdict.clear => AppColors.success,
      DiagnosisVerdict.violations =>
        report.severity == DiagnosisSeverity.high
            ? AppColors.danger
            : AppColors.issueWarning,
      DiagnosisVerdict.unknown => AppColors.info,
    };

    final icon = switch (report.verdict) {
      DiagnosisVerdict.clear => Icons.verified_rounded,
      DiagnosisVerdict.violations => Icons.report_gmailerrorred_rounded,
      DiagnosisVerdict.unknown => Icons.help_outline_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.verdict.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.severity.label,
                      style: textTheme.labelSmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
              MiniBadge(
                label: report.source.label,
                color: report.source == DiagnosisSource.ollama
                    ? AppColors.primary
                    : AppColors.info,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          report.summary,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        if (report.recommendations.isNotEmpty) ...[
          const SizedBox(height: 13),
          const SectionLabel(title: 'Рекомендации'),
          const SizedBox(height: 8),
          for (var i = 0; i < report.recommendations.length; i++)
            _Recommendation(index: i + 1, text: report.recommendations[i]),
        ],
        if (report.note != null && report.note!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppColors.info,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.note!,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              report.source == DiagnosisSource.ollama
                  ? Icons.memory_rounded
                  : Icons.offline_bolt_rounded,
              size: 11,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '${report.model} · ${report.latency.inMilliseconds} мс · '
                '${Formatters.clock(report.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(fontSize: 8.5),
              ),
            ),
            IconButton(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 13),
              tooltip: 'Скопировать отчёт',
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRun,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Повторить анализ'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 9),
              textStyle: const TextStyle(fontSize: 10.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final text = StringBuffer()
      ..writeln('CodeGraph · архитектурная диагностика')
      ..writeln('Файл: ${report.nodeId}')
      ..writeln('Вердикт: ${report.verdict.label}')
      ..writeln('Риск: ${report.severity.label}')
      ..writeln('Источник: ${report.source.label} (${report.model})')
      ..writeln()
      ..writeln(report.summary);
    if (report.recommendations.isNotEmpty) {
      text.writeln();
      text.writeln('Рекомендации:');
      for (var i = 0; i < report.recommendations.length; i++) {
        text.writeln('${i + 1}. ${report.recommendations[i]}');
      }
    }
    if (report.note != null) {
      text
        ..writeln()
        ..writeln(report.note);
    }

    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text.toString()));
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Отчёт скопирован в буфер обмена.')),
    );
  }
}

class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
