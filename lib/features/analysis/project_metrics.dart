import 'package:codegraph/features/project_scan/architecture_layer.dart';

class ProjectMetrics {
  const ProjectMetrics({
    required this.fileCount,
    required this.dependencyCount,
    required this.totalLines,
    required this.isolatedCount,
    required this.cycleCount,
    required this.layerViolationCount,
    required this.highCouplingCount,
    required this.averageOutgoing,
    required this.maxOutgoing,
    required this.healthScore,
    required this.layerFileCounts,
  });

  final int fileCount;
  final int dependencyCount;
  final int totalLines;
  final int isolatedCount;
  final int cycleCount;
  final int layerViolationCount;
  final int highCouplingCount;
  final double averageOutgoing;
  final int maxOutgoing;

  /// Условный индекс здоровья архитектуры: 0–100.
  final int healthScore;

  final Map<ArchitectureLayer, int> layerFileCounts;

  int get issueCount =>
      isolatedCount + cycleCount + layerViolationCount + highCouplingCount;

  bool get isHealthy => healthScore >= 80;
}
