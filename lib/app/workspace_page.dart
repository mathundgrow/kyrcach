import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:codegraph/core/services/project_picker.dart';
import 'package:codegraph/features/graph/graph_controller.dart';
import 'package:codegraph/features/graph/graph_canvas.dart';
import 'package:codegraph/features/inspector/inspector_collapse_tab.dart';
import 'package:codegraph/features/inspector/inspector_panel.dart';
import 'package:codegraph/features/project_scan/widgets/workspace_controller.dart';
import 'package:codegraph/features/project_scan/widgets/empty_workspace_view.dart';
import 'package:codegraph/features/project_scan/widgets/project_sidebar.dart';
import 'package:codegraph/features/project_scan/widgets/scan_error_view.dart';
import 'package:codegraph/features/project_scan/widgets/scanning_view.dart';
import 'package:codegraph/features/settings/settings_dialog.dart';
import 'package:codegraph/core/theme/app_colors.dart';
import 'widgets/how_it_works_dialog.dart';
import 'widgets/top_bar.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  /// Инспектор можно свернуть, чтобы освободить место графу.
  bool _inspectorCollapsed = false;

  GraphController? _graphController;
  String? _lastSelectedNodeId;

  @override
  void initState() {
    super.initState();
    final graph = context.read<GraphController>();
    _graphController = graph;
    _lastSelectedNodeId = graph.selectedNodeId;
    graph.addListener(_onGraphChanged);
  }

  @override
  void dispose() {
    _graphController?.removeListener(_onGraphChanged);
    super.dispose();
  }

  /// Выбор файла раскрывает инспектор: в нём лежит нужная информация.
  void _onGraphChanged() {
    final id = _graphController?.selectedNodeId;
    if (id == _lastSelectedNodeId) return;
    _lastSelectedNodeId = id;
    if (id != null && _inspectorCollapsed) {
      _setInspectorCollapsed(false);
    }
  }

  void _setInspectorCollapsed(bool value) {
    if (_inspectorCollapsed == value) return;
    setState(() => _inspectorCollapsed = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GraphController>().zoomToFit();
    });
  }

  Future<void> _openProject() async {
    try {
      final path = await ProjectPicker.pickDirectory();
      if (path == null || !mounted) return;
      await context.read<WorkspaceController>().openProject(path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось открыть диалог выбора папки: $error'),
        ),
      );
    }
  }

  void _openSettings() {
    SettingsDialog.show(context);
  }

  void _retry() {
    context.read<WorkspaceController>().rescan();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          TopBar(onOpenProject: _openProject, onOpenSettings: _openSettings),
          Expanded(child: _buildBody(workspace)),
        ],
      ),
    );
  }

  Widget _buildBody(WorkspaceController workspace) {
    return switch (workspace.status) {
      WorkspaceStatus.empty => EmptyWorkspaceView(
        onOpenProject: _openProject,
        onHowItWorks: () => HowItWorksDialog.show(context),
      ),
      WorkspaceStatus.scanning => ScanningView(
        path: workspace.lastRootPath,
        onCancel: workspace.clear,
      ),
      WorkspaceStatus.failure => ScanErrorView(
        failure: workspace.failure!,
        onRetry: _retry,
        onChooseAnother: _openProject,
      ),
      WorkspaceStatus.ready => _buildReady(workspace),
    };
  }

  Widget _buildReady(WorkspaceController workspace) {
    final graph = workspace.graph;
    if (graph == null || workspace.analysis == null) {
      return const SizedBox.shrink();
    }
    if (graph.files.isEmpty) {
      return EmptyGraphView(
        path: graph.rootPath,
        onChooseAnother: _openProject,
      );
    }

    final hasSelection = context.select<GraphController, bool>(
      (c) => c.selectedFile != null,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final sidebarWidth = width >= 1500 ? 300.0 : 276.0;
        final inspectorWidth = width >= 1500 ? 396.0 : 360.0;
        final showInspector = width >= 1280 || hasSelection;
        const railWidth = 42.0;
        final reservedWidth = !showInspector
            ? 0.0
            : (_inspectorCollapsed ? railWidth : inspectorWidth);

        // Инспектор накладывается поверх области графа: так язычок
        // сворачивания может лежать ровно на границе двух зон.
        return Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  ProjectSidebar(width: sidebarWidth),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: reservedWidth),
                      child: const GraphCanvas(),
                    ),
                  ),
                ],
              ),
            ),
            if (showInspector)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: reservedWidth,
                child: _inspectorCollapsed
                    ? const InspectorRail()
                    : InspectorPanel(
                        width: inspectorWidth,
                        onOpenSettings: _openSettings,
                      ),
              ),
            if (showInspector)
              Positioned(
                top: 0,
                bottom: 0,
                // Половина язычка (13 px из 26) лежит на графе.
                right: reservedWidth - 13,
                child: Center(
                  child: InspectorCollapseTab(
                    icon: _inspectorCollapsed
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    tooltip: _inspectorCollapsed
                        ? 'Развернуть инспектор'
                        : 'Свернуть инспектор',
                    onTap: () => _setInspectorCollapsed(!_inspectorCollapsed),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
