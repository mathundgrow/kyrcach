import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/layer_policy.dart';
import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/dependency_cycle.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/analysis/project_metrics.dart';
import 'cycle_detector.dart';

class ArchitectureAnalyzer {
  const ArchitectureAnalyzer({
    this.policy = const LayerPolicy(),
    this.cycleDetector = const CycleDetector(),
    this.highCouplingThreshold = 8,
  });

  final LayerPolicy policy;
  final CycleDetector cycleDetector;
  final int highCouplingThreshold;

  GraphAnalysis analyze(ProjectGraph graph) {
    final issues = <ArchitectureIssue>[];
    final cycles = cycleDetector.findCycles(graph);
    final cycleEdgeIds = <String>{};
    final violationEdgeIds = <String>{};

    final cycleNodeSets = <Set<String>>[];
    for (final cycle in cycles) {
      final nodeSet = cycle.nodeIds.toSet();
      cycleNodeSets.add(nodeSet);

      final cycleEdges = graph.edges
          .where(
            (edge) =>
                nodeSet.contains(edge.fromId) && nodeSet.contains(edge.toId),
          )
          .map((edge) => edge.id)
          .toSet();
      cycleEdgeIds.addAll(cycleEdges);

      final names = cycle.nodeIds
          .map((id) => graph.fileById(id)?.name ?? id)
          .take(6)
          .join(', ');
      final suffix = cycle.nodeIds.length > 6 ? ' и другие' : '';

      issues.add(
        ArchitectureIssue(
          id: 'cycle:${cycle.signature}',
          kind: IssueKind.circularDependency,
          severity: IssueSeverity.critical,
          title: 'Цикл из ${cycle.length} ${_filesWord(cycle.length)}',
          description:
              'Файлы зависят друг от друга по кругу: $names$suffix. '
              'Такой граф сложно тестировать и невозможно собирать слоями независимо.',
          nodeIds: cycle.nodeIds,
          edgeKeys: cycleEdges,
          metric: cycle.length,
        ),
      );
    }

    for (final edge in graph.edges) {
      final from = graph.fileById(edge.fromId);
      final to = graph.fileById(edge.toId);
      if (from == null || to == null) continue;
      // Точка входа — композиционный корень: ей разрешено собирать слои.
      if (from.isEntryPoint) continue;
      if (!policy.isViolation(from.layer, to.layer)) continue;

      violationEdgeIds.add(edge.id);
      final inCycle = cycleNodeSets.any(
        (nodes) => nodes.contains(edge.fromId) && nodes.contains(edge.toId),
      );

      issues.add(
        ArchitectureIssue(
          id: 'layer:${edge.id}',
          kind: IssueKind.layerViolation,
          severity: inCycle ? IssueSeverity.warning : IssueSeverity.critical,
          title: '${from.name} → ${to.name}',
          description:
              '${policy.describe(from.layer, to.layer)} Импорт: «${edge.uri}».',
          nodeIds: [edge.fromId, edge.toId],
          edgeKeys: {edge.id},
          metric: from.layer.index,
        ),
      );
    }

    for (final file in graph.files) {
      final incoming = graph.incomingCount(file.id);
      final outgoing = graph.outgoingCount(file.id);

      if (incoming == 0 && outgoing == 0) {
        issues.add(
          ArchitectureIssue(
            id: 'isolated:${file.id}',
            kind: IssueKind.isolatedFile,
            severity: IssueSeverity.warning,
            title: file.name,
            description:
                'Файл не импортирует другие модули и не используется никем. '
                'Вероятно, это мёртвый код или точка входа, забытая в графе.',
            nodeIds: [file.id],
            metric: 0,
          ),
        );
      }

      if (outgoing >= highCouplingThreshold) {
        issues.add(
          ArchitectureIssue(
            id: 'coupling:${file.id}',
            kind: IssueKind.highCoupling,
            severity: IssueSeverity.warning,
            title: file.name,
            description:
                'Файл импортирует $outgoing модулей. Высокая исходящая '
                'связанность усложняет повторное использование и тестирование.',
            nodeIds: [file.id],
            metric: outgoing,
          ),
        );
      }
    }

    issues.sort((a, b) {
      final bySeverity = a.severity.rank.compareTo(b.severity.rank);
      if (bySeverity != 0) return bySeverity;
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return a.title.compareTo(b.title);
    });

    final metrics = _metrics(graph, cycles, issues);
    return GraphAnalysis(
      metrics: metrics,
      issues: issues,
      cycles: cycles,
      cycleEdgeIds: cycleEdgeIds,
      violationEdgeIds: violationEdgeIds,
    );
  }

  ProjectMetrics _metrics(
    ProjectGraph graph,
    List<DependencyCycle> cycles,
    List<ArchitectureIssue> issues,
  ) {
    var isolated = 0;
    var violations = 0;
    var coupling = 0;
    var maxOutgoing = 0;
    var totalOutgoing = 0;

    for (final issue in issues) {
      switch (issue.kind) {
        case IssueKind.isolatedFile:
          isolated++;
        case IssueKind.layerViolation:
          violations++;
        case IssueKind.highCoupling:
          coupling++;
        case IssueKind.circularDependency:
          break;
      }
    }

    for (final file in graph.files) {
      final outgoing = graph.outgoingCount(file.id);
      totalOutgoing += outgoing;
      if (outgoing > maxOutgoing) maxOutgoing = outgoing;
    }

    final average = graph.fileCount == 0
        ? 0.0
        : totalOutgoing / graph.fileCount;
    final penalty =
        cycles.length * 12 + violations * 6 + isolated * 4 + coupling * 2;
    final health = graph.fileCount == 0
        ? 0
        : (100 - penalty).clamp(0, 100).toInt();

    return ProjectMetrics(
      fileCount: graph.fileCount,
      dependencyCount: graph.edgeCount,
      totalLines: graph.totalLines,
      isolatedCount: isolated,
      cycleCount: cycles.length,
      layerViolationCount: violations,
      highCouplingCount: coupling,
      averageOutgoing: average,
      maxOutgoing: maxOutgoing,
      healthScore: health,
      layerFileCounts: Map<ArchitectureLayer, int>.from(graph.layerCounts),
    );
  }

  String _filesWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'файл';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'файла';
    }
    return 'файлов';
  }
}
