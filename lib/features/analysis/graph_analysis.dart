import 'architecture_issue.dart';
import 'dependency_cycle.dart';
import 'project_metrics.dart';

class GraphAnalysis {
  GraphAnalysis({
    required this.metrics,
    required List<ArchitectureIssue> issues,
    required List<DependencyCycle> cycles,
    required Set<String> cycleEdgeIds,
    required Set<String> violationEdgeIds,
  }) : issues = List.unmodifiable(issues),
       cycles = List.unmodifiable(cycles),
       cycleEdgeIds = Set.unmodifiable(cycleEdgeIds),
       violationEdgeIds = Set.unmodifiable(violationEdgeIds),
       _issuesByNode = _indexByNode(issues);

  final ProjectMetrics metrics;
  final List<ArchitectureIssue> issues;
  final List<DependencyCycle> cycles;

  /// Рёбра, участвующие в циклах, — для красной подсветки на графе.
  final Set<String> cycleEdgeIds;

  /// Рёбра, нарушающие матрицу слоёв.
  final Set<String> violationEdgeIds;

  final Map<String, List<ArchitectureIssue>> _issuesByNode;

  static Map<String, List<ArchitectureIssue>> _indexByNode(
    List<ArchitectureIssue> issues,
  ) {
    final map = <String, List<ArchitectureIssue>>{};
    for (final issue in issues) {
      for (final nodeId in issue.nodeIds) {
        map.putIfAbsent(nodeId, () => []).add(issue);
      }
    }
    return map;
  }

  List<ArchitectureIssue> issuesForNode(String nodeId) =>
      _issuesByNode[nodeId] ?? const [];

  bool hasIssues(String nodeId) => _issuesByNode.containsKey(nodeId);

  bool hasCritical(String nodeId) => issuesForNode(
    nodeId,
  ).any((issue) => issue.severity == IssueSeverity.critical);

  int get criticalCount =>
      issues.where((issue) => issue.severity == IssueSeverity.critical).length;
}
