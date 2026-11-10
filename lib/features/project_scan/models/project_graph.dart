import 'architecture_layer.dart';
import 'dependency_edge.dart';
import 'source_file.dart';

/// Иммутабельный граф зависимостей проекта.
///
/// Внутри хранятся индексы входящих и исходящих рёбер, поэтому запросы
/// окружения узла не требуют повторного прохода по всему списку рёбер.
class ProjectGraph {

  final String rootPath;
  final String projectName;

  /// Каталог, который реально анализировался: `lib` или `.`.
  final String scannedRoot;
  final DateTime scannedAt;
  final Duration scanDuration;
  final int ignoredFileCount;
  final List<SourceFile> files;
  final List<DependencyEdge> edges;

  // словарь, подсчитывающий, сколько файлов лежит в каждом(core: 5...)
  final Map<ArchitectureLayer, int> layerCounts;

  final Map<String, SourceFile> _filesById;
  final Map<String, List<DependencyEdge>> _outgoing;
  final Map<String, List<DependencyEdge>> _incoming;


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

  /// Строит быстрый индекс файлов,
  /// Группирует связи
  /// Замораживает данные
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
    // Превращает обычный список файлов (List) в быстрый словарь
    final filesById = <String, SourceFile>{
      for (final file in files) file.id: file,
    };

    final outgoing = <String, List<DependencyEdge>>{};
    final incoming = <String, List<DependencyEdge>>{};
    // Группировка связей (outgoing и incoming)
    for (final edge in edges) {
      outgoing.putIfAbsent(edge.fromId, () => []).add(edge);
      incoming.putIfAbsent(edge.toId, () => []).add(edge);
    }

    // Создает счетчик для каждого архитектурного слоя и считает, сколько файлов лежит в каждом из них (например, сколько в Presentation, сколько в Data)
    final layerCounts = <ArchitectureLayer, int>{
      for (final layer in ArchitectureLayer.values) layer: 0,
    };
    for (final file in files) {
      layerCounts[file.layer] = (layerCounts[file.layer] ?? 0) + 1;
    }

    // нужны чтоб компонент приложения случайно не сломал приложение и не съел лишнюю память, пытаясь изменить граф на лету
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

  /// получает число 
  int get fileCount => files.length;

  /// получает чилсо количества связей
  int get edgeCount => edges.length;

  // суммарное количество строк кода во всем проекте
  int get totalLines => files.fold(0, (sum, file) => sum + file.lineCount);


  SourceFile? fileById(String id) => _filesById[id];

  /// сколько выходящих связей с файла
  List<DependencyEdge> outgoingEdges(String id) => _outgoing[id] ?? const [];
  
  /// показывает сколько входящих связей к файлу 
  List<DependencyEdge> incomingEdges(String id) => _incoming[id] ?? const [];

  /// возвращает список файлов, которые этот файл импортирует
  List<SourceFile> dependenciesOf(String id) => outgoingEdges(id)
      .map((edge) => _filesById[edge.toId])
      .whereType<SourceFile>()
      .toList(growable: false);

  /// возвращает список файлов, которые зависят от этого файла (кто его импортирует)
  List<SourceFile> dependentsOf(String id) => incomingEdges(id)
      .map((edge) => _filesById[edge.fromId])
      .whereType<SourceFile>()
      .toList(growable: false);

  /// проверяет сколько файлов используют данный файл
  int outgoingCount(String id) => outgoingEdges(id).length;

  /// проверяет сколько файл использует другие файлы
  int incomingCount(String id) => incomingEdges(id).length;

  /// проверяет, не импортирует ли файл сам себя (циклическая зависимость).
  bool hasSelfLoop(String id) =>
      outgoingEdges(id).any((edge) => edge.toId == id);
}
