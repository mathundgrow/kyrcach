import 'package:codegraph/features/project_scan/models/project_graph.dart';
import 'package:codegraph/features/analysis/dependency_cycle.dart';

/// Поиск сильно связанных компонент алгоритмом Тарьяна.
///
/// Компонента размера > 1 — это циклическая зависимость; компонента размера 1
/// считается циклом только при наличии петли на себя.
class CycleDetector {
  const CycleDetector();

  List<DependencyCycle> findCycles(ProjectGraph graph) {
    final adjacency = <String, List<String>>{
      for (final file in graph.files) file.id: <String>[],
    };
    for (final edge in graph.edges) {
      adjacency[edge.fromId]?.add(edge.toId);
    }

    var index = 0;
    final indices = <String, int>{};
    final lowLinks = <String, int>{};
    final onStack = <String>{};
    final stack = <String>[];
    final components = <List<String>>[];

    void connect(String node) {
      indices[node] = index;
      lowLinks[node] = index;
      index++;
      stack.add(node);
      onStack.add(node);

      for (final next in adjacency[node] ?? const <String>[]) {
        if (!indices.containsKey(next)) {
          connect(next);
          final nextLow = lowLinks[next]!;
          if (nextLow < lowLinks[node]!) lowLinks[node] = nextLow;
        } else if (onStack.contains(next)) {
          final nextIndex = indices[next]!;
          if (nextIndex < lowLinks[node]!) lowLinks[node] = nextIndex;
        }
      }

      if (lowLinks[node] == indices[node]) {
        final component = <String>[];
        while (stack.isNotEmpty) {
          final current = stack.removeLast();
          onStack.remove(current);
          component.add(current);
          if (current == node) break;
        }
        components.add(component);
      }
    }

    for (final file in graph.files) {
      if (!indices.containsKey(file.id)) connect(file.id);
    }

    final cycles = <DependencyCycle>[];
    for (final component in components) {
      final isLoop =
          component.length == 1 && graph.hasSelfLoop(component.first);
      if (component.length > 1 || isLoop) {
        cycles.add(DependencyCycle(_normalize(component)));
      }
    }

    cycles.sort((a, b) => a.signature.compareTo(b.signature));
    return cycles;
  }

  List<String> _normalize(List<String> nodes) {
    final sorted = List<String>.from(nodes);
    sorted.sort();
    return List.unmodifiable(sorted);
  }
}
