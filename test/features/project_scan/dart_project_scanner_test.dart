import 'dart:io';

import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/architecture_analyzer.dart';
import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/features/project_scan/dart_project_scanner.dart';
import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('codegraph_scan_');
    _write(root, 'pubspec.yaml', '''
name: demo_app
description: test
''');

    _write(root, 'lib/main.dart', '''
import 'package:demo_app/features/auth/presentation/login_page.dart';
import 'core/theme.dart';

void main() {}
''');

    _write(root, 'lib/features/auth/presentation/login_page.dart', '''
import 'package:flutter/material.dart';
import '../domain/user.dart';
import '../data/user_repository.dart';
import 'orphan.dart';
''');

    _write(root, 'lib/features/auth/domain/user.dart', '''
import '../data/user_repository.dart';

class User {}
''');

    _write(root, 'lib/features/auth/data/user_repository.dart', '''
import '../domain/user.dart';

class UserRepository {}
''');

    _write(
      root,
      'lib/features/auth/presentation/orphan.dart',
      'class Orphan {}',
    );
    _write(root, 'lib/features/auth/presentation/dead.dart', 'class Dead {}');
    _write(root, 'lib/core/theme.dart', 'const primary = 0;');
    _write(root, 'lib/generated.g.dart', '// generated');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('сканирует lib, разрешает package/relative импорты и слои', () async {
    const scanner = DartProjectScanner();
    final graph = await scanner.scan(root.path);

    expect(graph.projectName, 'demo_app');
    expect(graph.scannedRoot, 'lib');
    expect(graph.ignoredFileCount, 1);
    expect(graph.fileCount, 7);
    expect(graph.edgeCount, 7);

    expect(
      graph.fileById('lib/main.dart')?.layer,
      ArchitectureLayer.application,
    );
    expect(
      graph.fileById('lib/features/auth/domain/user.dart')?.layer,
      ArchitectureLayer.domain,
    );
    expect(
      graph.fileById('lib/features/auth/data/user_repository.dart')?.layer,
      ArchitectureLayer.data,
    );
    expect(
      graph.fileById('lib/features/auth/presentation/login_page.dart')?.layer,
      ArchitectureLayer.presentation,
    );

    expect(graph.outgoingCount('lib/main.dart'), 2);
    expect(
      graph
          .dependenciesOf('lib/features/auth/presentation/login_page.dart')
          .map((file) => file.name),
      containsAll(['user.dart', 'user_repository.dart', 'orphan.dart']),
    );

    final analysis = const ArchitectureAnalyzer().analyze(graph);
    expect(analysis.cycles, hasLength(1));
    expect(analysis.metrics.isolatedCount, 1);
    expect(analysis.metrics.layerViolationCount, 1);
    expect(
      analysis.issues.any(
        (issue) => issue.kind == IssueKind.circularDependency,
      ),
      isTrue,
    );
  });

  test('разрешает package-импорт при несовпадении имени пакета', () async {
    // BOM и комментарий в pubspec не должны ломать чтение имени, а импорт
    // с прежним именем пакета должен находиться по локальному пути.
    _write(root, 'pubspec.yaml', '\uFEFFname: old_name # legacy\n');

    const scanner = DartProjectScanner();
    final graph = await scanner.scan(root.path);

    expect(graph.projectName, 'old_name');
    expect(graph.outgoingCount('lib/main.dart'), 2);
  });

  test('выбрасывает ошибку для несуществующего каталога', () async {
    const scanner = DartProjectScanner();
    expect(
      () => scanner.scan(p.join(root.path, 'missing')),
      throwsA(isA<AppFailure>()),
    );
  });
}

void _write(Directory root, String relative, String content) {
  final file = File(p.join(root.path, relative));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
