import 'dart:io';

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/app/workspace_page.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';
import 'package:codegraph/features/inspector/ollama_api.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/search/search_graph.dart';
import 'package:codegraph/features/settings/ai_settings.dart';
import 'package:codegraph/features/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Верхняя панель: проект слева, поиск по центру, приложение справа.
/// Выбор файла автоматически раскрывает свёрнутый инспектор.
void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController graph;
  late InspectorController inspector;
  late SettingsController settings;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_home_');
    await _writeFile(root, 'pubspec.yaml', 'name: home_app\n');
    await _writeFile(root, 'lib/main.dart', 'void main() {}\n');

    workspace = WorkspaceController();
    await workspace.openProject(root.path);
    graph = GraphController(workspace);

    // Всегда падающий HTTP-клиент: инспектор работает в офлайн-режиме.
    final offlineApi = OllamaApi(
      client: MockClient(
        (request) async => http.Response('server is down', 500),
      ),
    );
    inspector = InspectorController(
      api: offlineApi,
      workspace: workspace,
      settingsProvider: () => AiSettings.defaults,
    );
    SharedPreferences.setMockInitialValues({});
    settings = SettingsController(await SharedPreferences.getInstance());
  });

  tearDown(() async {
    inspector.dispose();
    graph.dispose();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  Future<void> pumpWorkspace(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 847));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<GraphController>.value(value: graph),
          ChangeNotifierProvider<InspectorController>.value(value: inspector),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          Provider<SearchGraph>(create: (_) => const SearchGraph()),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const WorkspacePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('CodeGraph в правом углу — просто подпись, не кнопка', (
    tester,
  ) async {
    await pumpWorkspace(tester);

    expect(find.text('CodeGraph'), findsOneWidget);
    expect(find.text('АРХИТЕКТУРНЫЙ АНАЛИЗАТОР'), findsNothing);
    expect(find.text('⌘ K'), findsNothing);
    expect(find.byTooltip('На стартовый экран'), findsNothing);

    // Клик по названию ничего не делает: статус проекта не меняется.
    await tester.tap(find.text('CodeGraph'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(workspace.status, WorkspaceStatus.ready);
    expect(find.text('Открыть проект'), findsNothing);
  });

  testWidgets('выбор файла раскрывает свёрнутый инспектор', (tester) async {
    await pumpWorkspace(tester);

    expect(find.byTooltip('Свернуть инспектор'), findsOneWidget);
    await tester.tap(find.byTooltip('Свернуть инспектор'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Развернуть инспектор'), findsOneWidget);

    graph.selectNode(workspace.graph!.files.first.id);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Свернуть инспектор'), findsOneWidget);
    expect(find.byTooltip('Развернуть инспектор'), findsNothing);
  });
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
