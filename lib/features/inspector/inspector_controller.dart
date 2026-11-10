import 'package:flutter/foundation.dart';

import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/inspector/ai_diagnosis.dart';
import 'package:codegraph/features/inspector/ai_inspector.dart';
import 'package:codegraph/features/inspector/ai_status.dart';
import 'package:codegraph/features/inspector/inspection_request.dart';
import 'package:codegraph/features/inspector/ollama_api.dart';
import 'package:codegraph/features/project_scan/models/project_graph.dart';
import 'package:codegraph/features/project_scan/models/source_file.dart';
import 'package:codegraph/features/project_scan/widgets/workspace_controller.dart';
import 'package:codegraph/features/settings/ai_settings.dart';

enum AiConnection { checking, online, offline }

/// Статус Ollama и ИИ-отчёты по файлам.
class InspectorController extends ChangeNotifier {
  InspectorController({
    OllamaApi? api,
    required WorkspaceController workspace,
    required this.settingsProvider,
  }) : _inspector = AiInspector(api ?? OllamaApi()) {
    _workspace = workspace;
    _workspace.addListener(_onWorkspaceChanged);
    _lastGraph = _workspace.graph;
  }

  final AiInspector _inspector;
  late final WorkspaceController _workspace;

  /// Настройки читаются в момент запроса, чтобы смена модели применялась сразу.
  final AiSettings Function() settingsProvider;

  ProjectGraph? _lastGraph;
  AiConnection _connection = AiConnection.checking;
  AiStatus? _status;
  AppFailure? _statusFailure;
  String? _loadingNodeId;
  final Map<String, AiDiagnosis> _reports = {};
  final Map<String, AppFailure> _errors = {};

  AiConnection get connection => _connection;

  AiStatus? get status => _status;

  AppFailure? get statusFailure => _statusFailure;

  String? get loadingNodeId => _loadingNodeId;

  bool get isInspecting => _loadingNodeId != null;

  AiDiagnosis? reportFor(String nodeId) => _reports[nodeId];

  AppFailure? errorFor(String nodeId) => _errors[nodeId];

  bool isLoading(String nodeId) => _loadingNodeId == nodeId;

  Future<void> refreshStatus() async {
    _connection = AiConnection.checking;
    _statusFailure = null;
    notifyListeners();

    try {
      _status = await _inspector.checkStatus(settingsProvider());
      _connection = AiConnection.online;
      _statusFailure = null;
    } on AppFailure catch (failure) {
      _status = null;
      _connection = AiConnection.offline;
      _statusFailure = failure;
    }
    notifyListeners();
  }

  Future<void> inspect({
    required ProjectGraph graph,
    required GraphAnalysis analysis,
    required SourceFile file,
  }) async {
    if (_loadingNodeId == file.id) return;

    _loadingNodeId = file.id;
    _errors.remove(file.id);
    notifyListeners();

    try {
      final request = InspectionRequest.from(
        graph: graph,
        analysis: analysis,
        file: file,
      );
      _reports[file.id] = await _inspector.inspect(
        request: request,
        settings: settingsProvider(),
      );
      _errors.remove(file.id);
    } on AppFailure catch (failure) {
      _errors[file.id] = failure;
    }

    _loadingNodeId = null;
    notifyListeners();
  }

  void clearReports() {
    _reports.clear();
    _errors.clear();
    _loadingNodeId = null;
    notifyListeners();
  }

  void _onWorkspaceChanged() {
    if (identical(_lastGraph, _workspace.graph)) return;
    _lastGraph = _workspace.graph;
    clearReports();
  }

  @override
  void dispose() {
    _workspace.removeListener(_onWorkspaceChanged);
    super.dispose();
  }
}
