import 'package:codegraph/features/analysis/architecture_analyzer.dart';
import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:codegraph/features/search/search_graph.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/graph_factory.dart';

void main() {
  const search = SearchGraph();

  late final graph = testGraph(
    files: [
      testFile(
        'lib/features/discount/domain/discount_calculator.dart',
        layer: ArchitectureLayer.domain,
      ),
      testFile(
        'lib/features/discount/data/discount_repository.dart',
        layer: ArchitectureLayer.data,
      ),
      testFile(
        'lib/features/cart/presentation/cart_page.dart',
        layer: ArchitectureLayer.presentation,
      ),
      testFile(
        'lib/features/cart/domain/cart_entity.dart',
        layer: ArchitectureLayer.domain,
      ),
    ],
    edges: [
      testEdge(
        'lib/features/cart/presentation/cart_page.dart',
        'lib/features/discount/domain/discount_calculator.dart',
      ),
      testEdge(
        'lib/features/discount/domain/discount_calculator.dart',
        'lib/features/cart/domain/cart_entity.dart',
      ),
    ],
  );

  late final analysis = const ArchitectureAnalyzer().analyze(graph);

  test('находит файл по имени', () {
    final hits = search(
      graph: graph,
      analysis: analysis,
      query: 'discount_calculator',
    );
    expect(hits, isNotEmpty);
    expect(hits.first.file.name, 'discount_calculator.dart');
    expect(hits.first.reason, contains('имя'));
  });

  test('понимает архитектурный синоним «логика»', () {
    final hits = search(graph: graph, analysis: analysis, query: 'логика');
    expect(hits, isNotEmpty);
    expect(
      hits.every((hit) => hit.file.layer == ArchitectureLayer.domain),
      isTrue,
    );
  });

  test('находит слой data', () {
    final hits = search(graph: graph, analysis: analysis, query: 'data');
    expect(
      hits.map((hit) => hit.file.name),
      contains('discount_repository.dart'),
    );
  });

  test('пустой запрос ничего не возвращает', () {
    expect(search(graph: graph, analysis: analysis, query: '  '), isEmpty);
  });
}
