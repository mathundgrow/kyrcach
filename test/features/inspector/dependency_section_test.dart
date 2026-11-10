import 'dart:io';

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/core/theme/app_colors.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/inspector/dependency_section.dart';
import 'package:codegraph/features/project_scan/widgets/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// «и ещё N» должно раскрывать полный список зависимостей, а не оставаться
/// простым текстом.
void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController controller;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_deps_');
    await _writeFile(root, 'pubspec.yaml', 'name: deps_app\n');

    final imports = [
      for (var i = 0; i < 9; i++) "import 'dep_$i.dart';",
    ].join('\n');
    await _writeFile(root, 'lib/hub.dart', '$imports\n\nclass Hub {}\n');
    for (var i = 0; i < 9; i++) {
      await _writeFile(root, 'lib/dep_$i.dart', 'class Dep$i {}\n');
    }

    workspace = WorkspaceController();
    await workspace.openProject(root.path);
    controller = GraphController(workspace);
  });

  tearDown(() async {
    controller.dispose();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  testWidgets('«и ещё N» открывает плашку со всем списком', (tester) async {
    final graph = workspace.graph!;
    final hub = graph.files.firstWhere((file) => file.name == 'hub.dart');
    final dependencies = graph.dependenciesOf(hub.id);
    expect(dependencies, hasLength(9));

    await tester.pumpWidget(
      ChangeNotifierProvider<GraphController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: DependencySection(
                title: 'Импортирует',
                icon: Icons.arrow_outward_rounded,
                accent: AppColors.importEdge,
                files: dependencies,
                emptyText: 'Нет зависимостей',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // В инспекторе видно только первые шесть строк.
    expect(find.byType(DependencyRow), findsNWidgets(6));
    expect(find.text('и ещё 3'), findsOneWidget);

    await tester.tap(find.text('и ещё 3'));
    await tester.pumpAndSettle();

    final dialogRows = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(DependencyRow),
    );
    expect(dialogRows, findsNWidgets(9));
    expect(find.text('Импортирует · 9'), findsOneWidget);

    // Строка из скрытой части списка тоже должна открывать файл.
    final target = dependencies.firstWhere((file) => file.name == 'dep_8.dart');
    await tester.tap(find.text('dep_8.dart'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(controller.selectedNodeId, target.id);
    expect(controller.isFocusMode, isTrue);
  });
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
