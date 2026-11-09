import 'dart:io';

import 'package:codegraph/app/theme/app_theme.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';
import 'package:codegraph/features/inspector/inspector_collapse_tab.dart';
import 'package:codegraph/features/inspector/inspector_panel.dart';
import 'package:codegraph/features/inspector/ollama_api.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/settings/ai_settings.dart';
import 'package:codegraph/features/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Инспектор собран без отдельной плашки-заголовка: имя файла идёт сразу
/// сверху, связи стоят выше аномалий, а оценка ИИ отделена дивайдером.
void main() {
  late Directory root;
  late WorkspaceController workspace;
  late GraphController graph;
  late InspectorController inspector;
  late SettingsController settings;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('codegraph_inspector_');
    await _writeFile(root, 'pubspec.yaml', 'name: inspector_app\n');
    await _writeFile(root, 'lib/a.dart', "import 'b.dart';\n\nclass A {}\n");
    await _writeFile(root, 'lib/b.dart', 'class B {}\n');

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

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GraphController>.value(value: graph),
        ChangeNotifierProvider<InspectorController>.value(value: inspector),
        ChangeNotifierProvider<SettingsController>.value(value: settings),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }

  testWidgets('нет плашки-заголовка и дублирующего статуса ИИ', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final file = workspace.graph!.files.firstWhere(
      (item) => item.name == 'a.dart',
    );
    graph.selectNode(file.id);

    await tester.pumpWidget(
      wrap(InspectorPanel(width: 360, onOpenSettings: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Инспектор'), findsNothing);
    expect(find.text('ИИ-инспектор'), findsNothing);
    expect(find.text('offline'), findsNothing);
    expect(find.byTooltip('Снять выделение'), findsNothing);
  });

  testWidgets('имя файла идёт сверху без большого отступа', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final file = workspace.graph!.files.firstWhere(
      (item) => item.name == 'a.dart',
    );
    graph.selectNode(file.id);

    await tester.pumpWidget(
      wrap(InspectorPanel(width: 360, onOpenSettings: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final panelTop = tester.getTopLeft(find.byType(InspectorPanel)).dy;
    final nameTop = tester.getTopLeft(find.text('a.dart')).dy;
    expect(nameTop - panelTop, lessThan(40));
  });

  testWidgets('связи идут перед аномалиями, оценка ИИ — внизу', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final file = workspace.graph!.files.firstWhere(
      (item) => item.name == 'a.dart',
    );
    graph.selectNode(file.id);

    await tester.pumpWidget(
      wrap(InspectorPanel(width: 360, onOpenSettings: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));

    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;

    final imports = topOf('ИМПОРТИРУЕТ');
    final usedBy = topOf('ИСПОЛЬЗУЮТ');
    final issues = topOf('АНОМАЛИИ');
    final ai = topOf('ОЦЕНКА ИИ');

    expect(imports, lessThan(usedBy));
    expect(usedBy, lessThan(issues));
    expect(issues, lessThan(ai));
    expect(find.text('Локальная диагностика'), findsOneWidget);
  });

  testWidgets('язычок на границе сворачивает и разворачивает панель', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        Center(
          child: InspectorCollapseTab(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Свернуть инспектор',
            onTap: () => tapped++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Свернуть инспектор'), findsOneWidget);
    await tester.tap(find.byType(InspectorCollapseTab));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('свёрнутая полоса пустая: без подписи и цветной точки', (
    tester,
  ) async {
    final file = workspace.graph!.files.firstWhere(
      (item) => item.name == 'a.dart',
    );
    graph.selectNode(file.id);

    await tester.pumpWidget(wrap(const InspectorRail()));
    await tester.pump();

    expect(find.text('ИНСПЕКТОР'), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    expect(tester.getSize(find.byType(InspectorRail)).width, 42);
  });
}

Future<void> _writeFile(Directory root, String relative, String content) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
