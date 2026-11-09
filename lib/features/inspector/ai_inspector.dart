import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/inspector/ai_diagnosis.dart';
import 'package:codegraph/features/inspector/ai_status.dart';
import 'package:codegraph/features/inspector/diagnosis_response_parser.dart';
import 'package:codegraph/features/inspector/inspection_request.dart';
import 'package:codegraph/features/inspector/ollama_api.dart';
import 'package:codegraph/features/settings/ai_settings.dart';

/// Диагностика файла: сначала локальная модель Ollama,
/// при любой ошибке — детерминированная офлайн-эвристика.
class AiInspector {
  const AiInspector(this._api);

  final OllamaApi _api;

  /// Проверяет, что Ollama запущена, и возвращает список моделей.
  /// Бросает [AppFailure], если сервер недоступен.
  Future<AiStatus> checkStatus(AiSettings settings) async {
    final response = await _api.status(settings);
    return AiStatus(
      isOnline: true,
      model: settings.model,
      availableModels: response.models,
      latency: response.latency,
    );
  }

  /// Диагностирует файл через Ollama. Если модель недоступна или ответила
  /// ошибкой — возвращает офлайн-отчёт с пометкой в note.
  Future<AiDiagnosis> inspect({
    required InspectionRequest request,
    required AiSettings settings,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final raw = await _api.generate(settings, request.buildPrompt());
      stopwatch.stop();
      return const DiagnosisResponseParser().parse(
        rawResponse: raw,
        nodeId: request.nodeId,
        model: settings.model,
        latency: stopwatch.elapsed,
      );
    } on AppFailure catch (failure) {
      return offlineDiagnosis(request).copyWith(
        note:
            'Ollama недоступна: ${failure.message} '
            'Показан детерминированный офлайн-анализ без нейросети.',
      );
    }
  }
}

/// Офлайн-эвристика без нейросети: рекомендации по видам найденных аномалий.
AiDiagnosis offlineDiagnosis(InspectionRequest request) {
  final kinds = request.issueKinds.toSet();
  final recommendations = <String>{};

  if (kinds.contains(IssueKind.circularDependency)) {
    recommendations.add(
      'Разорвите цикл: вынесите общий контракт в слой domain и '
      'замените прямые импорты на абстракцию.',
    );
  }
  if (kinds.contains(IssueKind.layerViolation)) {
    recommendations.add(
      'Уберите обратную зависимость между слоями. '
      'Зависимости должны идти внутрь: UI → application → domain, data реализует интерфейсы.',
    );
  }
  if (kinds.contains(IssueKind.isolatedFile)) {
    recommendations.add(
      'Проверьте изолированный файл: удалите мёртвый код или подключите модуль '
      'к точке входа, если он должен использоваться.',
    );
  }
  if (kinds.contains(IssueKind.highCoupling)) {
    recommendations.add(
      'Разделите файл по ответственностям: вынесите часть импортов '
      'в отдельные сервисы или фасады, чтобы снизить связанность.',
    );
  }

  if (recommendations.isEmpty) {
    recommendations.addAll(const [
      'Критических структурных нарушений не найдено. Продолжайте держать '
          'зависимости направленными внутрь.',
      'Добавьте тесты на публичные контракты файла, чтобы зафиксировать поведение.',
      'Проверьте, что файл не разрастается: разделяйте ответственности заранее.',
    ]);
  }

  final hasCritical =
      kinds.contains(IssueKind.circularDependency) ||
      kinds.contains(IssueKind.layerViolation);
  final verdict = request.issues.isEmpty
      ? DiagnosisVerdict.clear
      : DiagnosisVerdict.violations;
  final severity = hasCritical
      ? DiagnosisSeverity.high
      : request.issues.isEmpty
      ? DiagnosisSeverity.low
      : DiagnosisSeverity.medium;

  final summary = request.issues.isEmpty
      ? 'Детерминированный анализ не нашёл аномалий у файла '
            '«${request.fileName}». Слой: ${request.layerTitle}, '
            'входящих связей: ${request.incomingCount}, исходящих: ${request.outgoingCount}.'
      : 'Найдено проблем: ${request.issues.length}. '
            'Файл «${request.fileName}» (${request.layerTitle}) имеет '
            '${request.outgoingCount} исходящих и ${request.incomingCount} входящих зависимостей.';

  return AiDiagnosis(
    nodeId: request.nodeId,
    verdict: verdict,
    summary: summary,
    recommendations: recommendations.take(6).toList(growable: false),
    source: DiagnosisSource.offline,
    model: 'offline-heuristics',
    latency: Duration.zero,
    createdAt: DateTime.now(),
    severity: severity,
  );
}
