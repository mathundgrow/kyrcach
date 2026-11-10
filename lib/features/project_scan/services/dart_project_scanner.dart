import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'package:codegraph/core/error/app_failure.dart';
import '../models/architecture_layer.dart';
import '../models/dependency_edge.dart';
import '../models/project_graph.dart';
import '../models/source_file.dart';
import 'layer_classifier.dart';
import 'import_directive_parser.dart';

/// Сканирует Dart-проект в отдельном изоляте, чтобы не блокировать UI.
///
/// Все ошибки (нет папки, нет доступа, неожиданный сбой) превращаются
/// в [AppFailure] с понятным сообщением.
class DartProjectScanner {
  const DartProjectScanner();

  Future<ProjectGraph> scan(String rootPath) async {
    try {
      return await Isolate.run(() => _scanProjectSync(rootPath));
    } on AppFailure {
      rethrow;
    } on FileSystemException catch (error) {
      throw AppFailure(
        message: 'Не удалось прочитать каталог проекта.',
        details: error.message,
        code: FailureCode.accessDenied,
      );
    } catch (error) {
      throw AppFailure(
        message: 'Во время сканирования произошла непредвиденная ошибка.',
        details: error.toString(),
        code: FailureCode.unknown,
      );
    }
  }
}

class _ScannedFile {
  const _ScannedFile({
    required this.absolutePath,
    required this.id,
    required this.name,
    required this.lineCount,
    required this.layer,
    required this.directives,
  });

  final String absolutePath;
  final String id;
  final String name;
  final int lineCount;
  final ArchitectureLayer layer;
  final List<ParsedDirective> directives;
}

const Set<String> _excludedDirectories = {
  '.git',
  '.dart_tool',
  '.idea',
  '.vscode',
  'build',
  'node_modules',
  'ios',
  'android',
  'macos',
  'windows',
  'linux',
  'web',
  'Pods',
  '.gradle',
};

const List<String> _generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
];

ProjectGraph _scanProjectSync(String inputPath) {
  final stopwatch = Stopwatch()..start();
  final root = Directory(inputPath);
  if (!root.existsSync()) {
    throw const AppFailure(
      message: 'Каталог не найден. Проверьте путь и права доступа.',
      code: FailureCode.notFound,
    );
  }

  final rootAbsolute = p.normalize(root.absolute.path);
  var projectRoot = rootAbsolute;
  var scanRoot = rootAbsolute;
  var scannedRoot = '.';

  final libDirectory = Directory(p.join(rootAbsolute, 'lib'));
  if (libDirectory.existsSync()) {
    scanRoot = libDirectory.path;
    scannedRoot = 'lib';
  } else if (p.basename(rootAbsolute) == 'lib') {
    final parent = p.dirname(rootAbsolute);
    if (File(p.join(parent, 'pubspec.yaml')).existsSync()) {
      projectRoot = parent;
      scannedRoot = 'lib';
    }
  }

  final projectName = _readProjectName(projectRoot) ?? p.basename(projectRoot);
  final parser = const ImportDirectiveParser();
  final classifier = const LayerClassifier();

  final scannedFiles = <_ScannedFile>[];
  var ignoredFiles = 0;

  final entities = Directory(
    scanRoot,
  ).listSync(recursive: true, followLinks: false);
  for (final entity in entities) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.dart')) continue;

    final relativeToRoot = p.relative(entity.path, from: projectRoot);
    final id = _toPosix(relativeToRoot);
    if (_isExcluded(id)) continue;

    final name = p.basename(entity.path);
    if (_generatedSuffixes.any(name.endsWith)) {
      ignoredFiles++;
      continue;
    }

    String source;
    try {
      source = entity.readAsStringSync();
    } on FileSystemException {
      ignoredFiles++;
      continue;
    }

    scannedFiles.add(
      _ScannedFile(
        absolutePath: p.normalize(entity.path),
        id: id,
        name: name,
        lineCount: _countLines(source),
        layer: classifier.classify(id),
        directives: parser.parse(source),
      ),
    );
  }

  scannedFiles.sort((a, b) => a.id.compareTo(b.id));
  final knownIds = scannedFiles.map((file) => file.id).toSet();
  final edges = <DependencyEdge>[];
  final edgeKeys = <String>{};

  for (final file in scannedFiles) {
    for (final directive in file.directives) {
      final targetId = _resolveTarget(
        file: file,
        uri: directive.uri,
        projectRoot: projectRoot,
        packageName: projectName,
        knownIds: knownIds,
      );
      if (targetId == null) continue;

      final key = '${file.id}|$targetId';
      if (!edgeKeys.add(key)) continue;

      edges.add(
        DependencyEdge(
          fromId: file.id,
          toId: targetId,
          uri: directive.uri,
          kind: directive.uri.startsWith('package:')
              ? DependencyKind.package
              : DependencyKind.local,
          directive: directive.directive,
        ),
      );
    }
  }

  edges.sort((a, b) {
    final bySource = a.fromId.compareTo(b.fromId);
    return bySource != 0 ? bySource : a.toId.compareTo(b.toId);
  });

  stopwatch.stop();

  return ProjectGraph.create(
    rootPath: projectRoot,
    projectName: projectName,
    scannedRoot: scannedRoot,
    scannedAt: DateTime.now(),
    scanDuration: stopwatch.elapsed,
    ignoredFileCount: ignoredFiles,
    files: [
      for (final file in scannedFiles)
        SourceFile(
          id: file.id,
          name: file.name,
          relativePath: file.id,
          absolutePath: file.absolutePath,
          layer: file.layer,
          lineCount: file.lineCount,
        ),
    ],
    edges: edges,
  );
}

String? _resolveTarget({
  required _ScannedFile file,
  required String uri,
  required String projectRoot,
  required String packageName,
  required Set<String> knownIds,
}) {
  if (uri.startsWith('dart:')) return null;
  if (uri.contains(':') && !uri.startsWith('package:')) return null;

  String? candidatePath;

  if (uri.startsWith('package:')) {
    final withoutScheme = uri.substring('package:'.length);
    final slashIndex = withoutScheme.indexOf('/');
    if (slashIndex <= 0) return null;

    final package = withoutScheme.substring(0, slashIndex);
    var rest = withoutScheme.substring(slashIndex + 1);
    if (!rest.endsWith('.dart')) rest = '$rest.dart';
    final localPath = p.normalize(p.join(projectRoot, 'lib', rest));
    if (!p.isWithin(projectRoot, localPath)) return null;

    // Имя пакета в pubspec может не совпадать с именем каталога (монорепозиторий,
    // переименование, BOM/комментарий в pubspec). Если файл с таким путём есть
    // в сканируемом проекте — считаем импорт локальным, иначе игнорируем.
    if (package != packageName) {
      final localId = _toPosix(p.relative(localPath, from: projectRoot));
      return knownIds.contains(localId) ? localId : null;
    }

    candidatePath = localPath;
  } else {
    final cleanUri = Uri.decodeComponent(uri.split('?').first);
    candidatePath = p.isAbsolute(cleanUri)
        ? cleanUri
        : p.join(p.dirname(file.absolutePath), cleanUri);
  }

  if (!candidatePath.endsWith('.dart')) {
    candidatePath = '$candidatePath.dart';
  }

  final normalized = p.normalize(candidatePath);
  if (!p.isWithin(projectRoot, normalized)) return null;

  final id = _toPosix(p.relative(normalized, from: projectRoot));
  return knownIds.contains(id) ? id : null;
}

String? _readProjectName(String projectRoot) {
  final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  try {
    final content = pubspec.readAsStringSync().replaceFirst('\uFEFF', '');
    final match = RegExp(
      r'''^name:\s*['"]?([A-Za-z0-9_]+)['"]?\s*(?:#.*)?$''',
      multiLine: true,
    ).firstMatch(content);
    return match?.group(1);
  } on FileSystemException {
    return null;
  }
}

bool _isExcluded(String relativePath) {
  final segments = relativePath.split('/');
  for (final segment in segments) {
    if (segment.startsWith('.')) return true;
    if (_excludedDirectories.contains(segment)) return true;
  }
  return false;
}

int _countLines(String source) {
  if (source.isEmpty) return 0;
  final newlines = '\n'.allMatches(source).length;
  return source.endsWith('\n') ? newlines : newlines + 1;
}

String _toPosix(String path) => path.replaceAll('\\', '/');
