import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/architecture_analyzer.dart';
import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/graph_factory.dart';

void main() {
  test('находит цикл, нарушение слоёв, dead code и связанность', () {
    final graph = testGraph(
      files: [
        testFile('lib/main.dart', layer: ArchitectureLayer.presentation),
        testFile(
          'lib/features/a/presentation/page.dart',
          layer: ArchitectureLayer.presentation,
        ),
        testFile(
          'lib/features/a/domain/entity.dart',
          layer: ArchitectureLayer.domain,
        ),
        testFile(
          'lib/features/a/data/repository.dart',
          layer: ArchitectureLayer.data,
        ),
        testFile(
          'lib/features/a/core/util.dart',
          layer: ArchitectureLayer.core,
        ),
        testFile('lib/orphan.dart', layer: ArchitectureLayer.unknown),
      ],
      edges: [
        testEdge('lib/main.dart', 'lib/features/a/presentation/page.dart'),
        testEdge(
          'lib/features/a/presentation/page.dart',
          'lib/features/a/domain/entity.dart',
        ),
        testEdge(
          'lib/features/a/presentation/page.dart',
          'lib/features/a/core/util.dart',
        ),
        testEdge(
          'lib/features/a/domain/entity.dart',
          'lib/features/a/data/repository.dart',
        ),
        testEdge(
          'lib/features/a/data/repository.dart',
          'lib/features/a/domain/entity.dart',
        ),
        testEdge(
          'lib/features/a/domain/entity.dart',
          'lib/features/a/presentation/page.dart',
        ),
        testEdge(
          'lib/features/a/core/util.dart',
          'lib/features/a/core/util.dart',
        ),
      ],
    );

    const analyzer = ArchitectureAnalyzer(highCouplingThreshold: 2);
    final analysis = analyzer.analyze(graph);

    expect(analysis.cycles, hasLength(2));
    expect(analysis.metrics.cycleCount, 2);
    expect(analysis.metrics.isolatedCount, 1);
    expect(analysis.metrics.layerViolationCount, 2);
    expect(analysis.metrics.highCouplingCount, 2);
    expect(analysis.metrics.issueCount, 7);

    expect(
      analysis
          .issuesForNode('lib/features/a/domain/entity.dart')
          .map((issue) => issue.kind),
      containsAll([IssueKind.layerViolation, IssueKind.circularDependency]),
    );
    expect(analysis.hasCritical('lib/features/a/data/repository.dart'), isTrue);

    final critical = analysis.issues.first;
    expect(critical.severity, IssueSeverity.critical);
    expect(analysis.cycleEdgeIds, isNotEmpty);
    expect(analysis.violationEdgeIds, isNotEmpty);
  });

  test('entry point не считается нарушением слоёв', () {
    final graph = testGraph(
      files: [
        testFile('lib/main.dart', layer: ArchitectureLayer.application),
        testFile(
          'lib/features/a/presentation/page.dart',
          layer: ArchitectureLayer.presentation,
        ),
      ],
      edges: [
        testEdge('lib/main.dart', 'lib/features/a/presentation/page.dart'),
      ],
    );

    final analysis = const ArchitectureAnalyzer().analyze(graph);
    expect(analysis.metrics.layerViolationCount, 0);
  });

  test('пустой проект даёт нулевое здоровье', () {
    final graph = testGraph(files: const [], edges: const []);
    final analysis = const ArchitectureAnalyzer().analyze(graph);
    expect(analysis.metrics.healthScore, 0);
    expect(analysis.issues, isEmpty);
  });
}
