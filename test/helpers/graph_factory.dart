import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:codegraph/features/project_scan/dependency_edge.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/source_file.dart';

SourceFile testFile(String id, {ArchitectureLayer? layer, int lineCount = 10}) {
  final name = id.split('/').last;
  return SourceFile(
    id: id,
    name: name,
    relativePath: id,
    absolutePath: '/tmp/demo/$id',
    layer: layer ?? ArchitectureLayer.unknown,
    lineCount: lineCount,
  );
}

DependencyEdge testEdge(String from, String to) {
  return DependencyEdge(
    fromId: from,
    toId: to,
    uri: to,
    kind: DependencyKind.local,
    directive: ImportDirective.import,
  );
}

ProjectGraph testGraph({
  required List<SourceFile> files,
  required List<DependencyEdge> edges,
}) {
  return ProjectGraph.create(
    rootPath: '/tmp/demo',
    projectName: 'demo_app',
    scannedRoot: 'lib',
    scannedAt: DateTime(2026, 10, 28),
    scanDuration: const Duration(milliseconds: 120),
    ignoredFileCount: 0,
    files: files,
    edges: edges,
  );
}
