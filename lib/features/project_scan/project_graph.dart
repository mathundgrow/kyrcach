import 'architecture_layer.dart';
import 'dependency_edge.dart';
import 'source_file.dart';

/// Иммутабельный граф зависимостей проекта.
///
/// Внутри хранятся индексы входящих и исходящих рёбер, поэтому запросы
/// окружения узла не требуют повторного прохода по всему списку рёбер.
class ProjectGraph {
  ProjectGraph._({
    required this.rootPath,
    required this.projectName,
    required this.scannedRoot,
    required this.scannedAt,
    required this.scanDuration,
    required this.ignoredFileCount,
    required this.files,
    required this.edges,
    required this._filesById,
    required this._outgoing,
    required this._incoming,
    required this.layerCounts,
  });

  factory ProjectGraph.create({
    required String rootPath,
    required String projectName,
    required String scannedRoot,
    required DateTime scannedAt,
    required Duration scanDuration,
    required int ignoredFileCount,
    required List<SourceFile> files,
    required List<DependencyEdge> edges,
  }) {
    final filesById = <String, SourceFile>{
      for (final file in files) file.id: file,
    };
    final outgoing = <String, List<DependencyEdge>>{};
    final incoming = <String, List<DependencyEdge>>{};
    for (final edge in edges) {
      outgoing.putIfAbsent(edge.fromId, () => []).add(edge);
      incoming.putIfAbsent(edge.toId, () => []).add(edge);
    }
    final layerCounts = <ArchitectureLayer, int>{
      for (final layer in ArchitectureLayer.values) layer: 0,
    };
    for (final file in files) {
      layerCounts[file.layer] = (layerCounts[file.layer] ?? 0) + 1;
    }

    final immutableOutgoing = <String, List<DependencyEdge>>{
      for (final entry in outgoing.entries)
        entry.key: List<DependencyEdge>.unmodifiable(entry.value),
    };
    final immutableIncoming = <String, List<DependencyEdge>>{
      for (final entry in incoming.entries)
        entry.key: List<DependencyEdge>.unmodifiable(entry.value),
    };

    return ProjectGraph._(
      rootPath: rootPath,
      projectName: projectName,
      scannedRoot: scannedRoot,
      scannedAt: scannedAt,
      scanDuration: scanDuration,
      ignoredFileCount: ignoredFileCount,
      files: List<SourceFile>.unmodifiable(files),
      edges: List<DependencyEdge>.unmodifiable(edges),
      filesById: Map<String, SourceFile>.unmodifiable(filesById),
      outgoing: Map<String, List<DependencyEdge>>.unmodifiable(
        immutableOutgoing,
      ),
      incoming: Map<String, List<DependencyEdge>>.unmodifiable(
        immutableIncoming,
      ),
      layerCounts: Map<ArchitectureLayer, int>.unmodifiable(layerCounts),
    );
  }

  final String rootPath;
  final String projectName;

  /// Каталог, который реально анализировался: `lib` или `.`.
  final String scannedRoot;
  final DateTime scannedAt;
  final Duration scanDuration;
  final int ignoredFileCount;
  final List<SourceFile> files;
  final List<DependencyEdge> edges;
  final Map<ArchitectureLayer, int> layerCounts;

  final Map<String, SourceFile> _filesById;
  final Map<String, List<DependencyEdge>> _outgoing;
  final Map<String, List<DependencyEdge>> _incoming;

  int get fileCount => files.length;

  int get edgeCount => edges.length;

  int get totalLines => files.fold(0, (sum, file) => sum + file.lineCount);

  SourceFile? fileById(String id) => _filesById[id];

  List<DependencyEdge> outgoingEdges(String id) => _outgoing[id] ?? const [];

  List<DependencyEdge> incomingEdges(String id) => _incoming[id] ?? const [];

  List<SourceFile> dependenciesOf(String id) => outgoingEdges(id)
      .map((edge) => _filesById[edge.toId])
      .whereType<SourceFile>()
      .toList(growable: false);

  List<SourceFile> dependentsOf(String id) => incomingEdges(id)
      .map((edge) => _filesById[edge.fromId])
      .whereType<SourceFile>()
      .toList(growable: false);

  int outgoingCount(String id) => outgoingEdges(id).length;

  int incomingCount(String id) => incomingEdges(id).length;

  bool hasSelfLoop(String id) =>
      outgoingEdges(id).any((edge) => edge.toId == id);
}
