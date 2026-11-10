import 'architecture_layer.dart';

/// Узел графа — один Dart-файл проекта.
class SourceFile {
  /// Относительный POSIX-путь от корня проекта. Используется как стабильный id.
  /// нужен чтоб отличать один файл от другого
  final String id;

  final String name;
  final String relativePath;
  final String absolutePath;
  final ArchitectureLayer layer;
  final int lineCount;

  const SourceFile({
    required this.id,
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.layer,
    required this.lineCount,
  });

  bool get isEntryPoint => name == 'main.dart';

  String get directory {
    final index = relativePath.lastIndexOf('/');
    return index < 0 ? '' : relativePath.substring(0, index);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SourceFile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SourceFile($id)';
}
