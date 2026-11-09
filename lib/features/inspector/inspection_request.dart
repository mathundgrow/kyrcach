import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/source_file.dart';

/// Снимок файла для ИИ-диагностики: связи, слой и найденные аномалии.
/// В промпт не попадает исходный код — только эта метаинформация.
class InspectionRequest {
  const InspectionRequest({
    required this.nodeId,
    required this.projectName,
    required this.fileName,
    required this.filePath,
    required this.layerTitle,
    required this.lineCount,
    required this.incomingCount,
    required this.outgoingCount,
    required this.incoming,
    required this.outgoing,
    required this.issues,
    required this.issueKinds,
  });

  /// Собирает запрос из графа и анализа для конкретного файла.
  factory InspectionRequest.from({
    required ProjectGraph graph,
    required GraphAnalysis analysis,
    required SourceFile file,
  }) {
    final outgoingEdges = graph.outgoingEdges(file.id);
    final incomingEdges = graph.incomingEdges(file.id);
    final issues = analysis.issuesForNode(file.id);

    return InspectionRequest(
      nodeId: file.id,
      projectName: graph.projectName,
      fileName: file.name,
      filePath: file.relativePath,
      layerTitle: file.layer.title,
      lineCount: file.lineCount,
      incomingCount: incomingEdges.length,
      outgoingCount: outgoingEdges.length,
      incoming: incomingEdges
          .map(
            (edge) =>
                '${edge.fromId} (${edge.directive.keyword} «${edge.uri}»)',
          )
          .toList(growable: false),
      outgoing: outgoingEdges
          .map(
            (edge) => '${edge.toId} (${edge.directive.keyword} «${edge.uri}»)',
          )
          .toList(growable: false),
      issues: issues
          .map((issue) => '${issue.kind.title}: ${issue.description}')
          .toList(growable: false),
      issueKinds: issues.map((issue) => issue.kind).toList(growable: false),
    );
  }

  final String nodeId;
  final String projectName;
  final String fileName;
  final String filePath;
  final String layerTitle;
  final int lineCount;
  final int incomingCount;
  final int outgoingCount;
  final List<String> incoming;
  final List<String> outgoing;
  final List<String> issues;
  final List<IssueKind> issueKinds;

  String buildPrompt() {
    final outgoingText = outgoing.isEmpty
        ? 'нет'
        : outgoing.map((item) => '  - $item').join('\n');
    final incomingText = incoming.isEmpty
        ? 'нет'
        : incoming.map((item) => '  - $item').join('\n');
    final issuesText = issues.isEmpty
        ? 'автоматических аномалий не найдено'
        : issues.map((item) => '  - $item').join('\n');

    return '''
Ты — строгий локальный архитектурный инспектор Dart/Flutter-проектов.
Анализируй только факты ниже. Не выдумывай файлы и зависимости.
Оцени архитектурное здоровье одного файла и верни практические рекомендации на русском языке.

Проект: $projectName
Файл: $filePath
Слой: $layerTitle
Строк кода: $lineCount
Входящие зависимости: $incomingCount
Исходящие зависимости: $outgoingCount

Исходящие зависимости:
$outgoingText

Входящие зависимости:
$incomingText

Найденные детерминированным анализатором аномалии:
$issuesText

Критерии:
- циклические зависимости и обратные зависимости между слоями — критичны;
- изолированные файлы и высокая связанность — предупреждения;
- если нарушений нет, verdict = "ok".

Ответ верни ТОЛЬКО валидным JSON без markdown:
{"verdict":"ok|violations","severity":"low|medium|high","summary":"краткий вывод","recommendations":["шаг 1","шаг 2"]}
''';
  }
}
