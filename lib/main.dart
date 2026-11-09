import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:codegraph/app/app.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/inspector/inspector_controller.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/search/search_graph.dart';
import 'package:codegraph/features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final settings = SettingsController(preferences);
  await settings.load();

  final workspace = WorkspaceController();
  final graph = GraphController(workspace);
  final inspector = InspectorController(
    workspace: workspace,
    settingsProvider: () => settings.settings,
  );
  unawaited(inspector.refreshStatus());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: workspace),
        ChangeNotifierProvider.value(value: graph),
        ChangeNotifierProvider.value(value: inspector),
        Provider<SearchGraph>.value(value: const SearchGraph()),
      ],
      child: const CodeGraphApp(),
    ),
  );
}
