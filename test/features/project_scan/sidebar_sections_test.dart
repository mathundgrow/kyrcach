import 'dart:io';

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/project_scan/project_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// Блоки «Слои» и «Проблемы» в левой панели можно свернуть.
void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController graph;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_sidebar_');
    await _writeFile(root, 'pubspec.yaml', 'name: sidebar_app\n');
    await _writeFile(root, 'lib/main.dart', 'void main() {}\n');
    await _writeFile(root, 'lib/presentation/a.dart', 'class A {}\n');

    workspace = WorkspaceController();
    await workspace.openProject(root.path);
    graph = GraphController(workspace);
  });

  tearDown(() async {
    graph.dispose();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  testWidgets('слои и проблемы сворачиваются по клику', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<GraphController>.value(
        value: graph,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: ProjectSidebar(width: 280)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Presentation'), findsOneWidget);
    expect(find.text('ПРОБЛЕМЫ'), findsOneWidget);

    await tester.tap(find.text('СЛОИ'));
    await tester.pump();
    expect(find.text('Presentation'), findsNothing);

    await tester.tap(find.text('СЛОИ'));
    await tester.pump();
    expect(find.text('Presentation'), findsOneWidget);

    await tester.tap(find.text('ПРОБЛЕМЫ'));
    await tester.pump();
    expect(find.text('ПРОБЛЕМЫ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('клик по слою показывает только его, глазик скрывает слой', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<GraphController>.value(
        value: graph,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: ProjectSidebar(width: 280)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Presentation'));
    await tester.pump();

    expect(graph.soloLayer, ArchitectureLayer.presentation);
    expect(graph.visibleFiles, isNotEmpty);
    expect(
      graph.visibleFiles.every(
        (file) => file.layer == ArchitectureLayer.presentation,
      ),
      isTrue,
    );

    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pump();

    expect(graph.isLayerVisible(ArchitectureLayer.presentation), isFalse);
    expect(graph.visibleFiles, isEmpty);
  });

  testWidgets('галочка «проверено» пересчитывает аномалии и здоровье', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<GraphController>.value(
        value: graph,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: ProjectSidebar(width: 280)),
        ),
      ),
    );
    await tester.pump();

    final issue = graph.unresolvedIssues.first;
    final beforeCount = graph.unresolvedIssueCount;
    final beforeHealth = graph.adjustedHealthScore;
    expect(beforeCount, greaterThan(0));

    await tester.tap(find.byTooltip('Отметить как проверенное').first);
    await tester.pump();

    expect(graph.isIssueResolved(issue.id), isTrue);
    expect(graph.unresolvedIssueCount, beforeCount - 1);
    expect(graph.adjustedHealthScore, greaterThan(beforeHealth));
    expect(find.byTooltip('Снова считать аномалией'), findsOneWidget);

    await tester.tap(find.byTooltip('Снова считать аномалией').first);
    await tester.pump();

    expect(graph.isIssueResolved(issue.id), isFalse);
    expect(graph.unresolvedIssueCount, beforeCount);
    expect(graph.adjustedHealthScore, beforeHealth);
  });
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
