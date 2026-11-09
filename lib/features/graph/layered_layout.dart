import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Размер карточки узла. Раскладка и отрисовка используют одни и те же
/// константы, поэтому сцена и рёбра всегда совпадают с реальными карточками.
const double kNodeWidth = 224;
const double kNodeHeight = 82;

/// Результат слоёной раскладки: координаты узлов и размер всей сцены.
class LayeredLayout {
  const LayeredLayout({required this.positions, required this.size});

  /// Левый верхний угол карточки для каждого идентификатора узла.
  final Map<String, Offset> positions;

  /// Полный размер сцены, включая все колонки и отступы.
  final Size size;

  Offset? centerOf(String nodeId) {
    final position = positions[nodeId];
    if (position == null) return null;
    return position + const Offset(kNodeWidth / 2, kNodeHeight / 2);
  }
}

/// Детерминированная слоёная раскладка графа.
///
/// Узлы группируются по архитектурным слоям: каждый слой занимает одну или
/// несколько вертикальных колонок. Внутри колонки узлы сортируются по имени,
/// поэтому повторная раскладка одного и того же графа даёт одинаковый результат.
///
/// Раскладка намеренно не использует силовые алгоритмы: для проекта из
/// десятков файлов они дают нестабильные и слишком разреженные координаты,
/// из-за чего узлы становятся нечитаемыми.
LayeredLayout computeLayeredLayout({
  required Iterable<String> nodeIds,
  required Map<String, int> columnByNodeId,
  int maxRowsPerColumn = 12,
  double horizontalGap = 44,
  double verticalGap = 20,
}) {
  final ids = nodeIds.toSet().toList()..sort();
  if (ids.isEmpty) {
    return const LayeredLayout(positions: {}, size: Size.zero);
  }

  final fallbackColumn =
      columnByNodeId.values.fold<int>(0, (a, b) => math.max(a, b)) + 1;

  final byColumn = <int, List<String>>{};
  for (final id in ids) {
    final column = columnByNodeId[id] ?? fallbackColumn;
    byColumn.putIfAbsent(column, () => []).add(id);
  }

  final orderedColumns = byColumn.keys.toList()..sort();

  // Один слой может не поместиться в колонку — тогда он занимает несколько
  // соседних колонок, сохраняя порядок узлов.
  final visualColumns = <List<String>>[];
  for (final column in orderedColumns) {
    final nodes = byColumn[column]!;
    for (var start = 0; start < nodes.length; start += maxRowsPerColumn) {
      final end = math.min(start + maxRowsPerColumn, nodes.length);
      visualColumns.add(nodes.sublist(start, end));
    }
  }

  final positions = <String, Offset>{};
  var x = 0.0;
  var maxBottom = 0.0;

  for (final column in visualColumns) {
    var y = 0.0;
    for (final id in column) {
      positions[id] = Offset(x, y);
      y += kNodeHeight + verticalGap;
    }
    maxBottom = math.max(maxBottom, y - verticalGap);
    x += kNodeWidth + horizontalGap;
  }

  final width = visualColumns.isEmpty ? 0.0 : x - horizontalGap;
  return LayeredLayout(positions: positions, size: Size(width, maxBottom));
}
