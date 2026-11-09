import 'package:codegraph/features/graph/layered_layout.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('раскладывает узлы по колонкам слоёв слева направо', () {
    final layout = computeLayeredLayout(
      nodeIds: const ['presentation_page', 'domain_entity', 'data_repository'],
      columnByNodeId: const {
        'presentation_page': 0,
        'domain_entity': 2,
        'data_repository': 3,
      },
    );

    final page = layout.positions['presentation_page']!;
    final entity = layout.positions['domain_entity']!;
    final repository = layout.positions['data_repository']!;

    expect(page.dx, lessThan(entity.dx));
    expect(entity.dx, lessThan(repository.dx));
    expect(layout.size.width, greaterThan(0));
    expect(layout.size.height, greaterThan(0));
  });

  test('сортирует узлы внутри колонки и сохраняет порядок между запусками', () {
    final firstRun = computeLayeredLayout(
      nodeIds: const ['b_file', 'a_file', 'c_file'],
      columnByNodeId: const {'a_file': 0, 'b_file': 0, 'c_file': 0},
    );
    final secondRun = computeLayeredLayout(
      nodeIds: const ['c_file', 'b_file', 'a_file'],
      columnByNodeId: const {'a_file': 0, 'b_file': 0, 'c_file': 0},
    );

    expect(
      firstRun.positions['a_file']!.dy,
      lessThan(firstRun.positions['b_file']!.dy),
    );
    expect(
      firstRun.positions['b_file']!.dy,
      lessThan(firstRun.positions['c_file']!.dy),
    );
    expect(firstRun.positions['a_file']!.dx, firstRun.positions['b_file']!.dx);
    expect(secondRun.positions, firstRun.positions);
  });

  test('переносит переполненную колонку в соседнюю', () {
    final layout = computeLayeredLayout(
      nodeIds: const ['a', 'b', 'c'],
      columnByNodeId: const {'a': 0, 'b': 0, 'c': 0},
      maxRowsPerColumn: 2,
      horizontalGap: 40,
    );

    final a = layout.positions['a']!;
    final b = layout.positions['b']!;
    final c = layout.positions['c']!;

    expect(a.dx, b.dx);
    expect(c.dx, greaterThan(a.dx));
    expect(c.dy, a.dy);
  });

  test('пустой граф даёт нулевой размер', () {
    final layout = computeLayeredLayout(
      nodeIds: const [],
      columnByNodeId: const {},
    );

    expect(layout.positions, isEmpty);
    expect(layout.size, Size.zero);
  });
}
