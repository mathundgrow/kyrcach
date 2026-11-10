import 'package:flutter/foundation.dart';

import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/features/analysis/architecture_analyzer.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/project_scan/services/dart_project_scanner.dart';
import 'package:codegraph/features/project_scan/models/project_graph.dart';

enum WorkspaceStatus { empty, scanning, ready, failure }

/// Сканирует выбранную папку и хранит текущий граф с результатами анализа.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    this.scanner = const DartProjectScanner(),
    this.analyzer = const ArchitectureAnalyzer(),
  });

  final DartProjectScanner scanner;
  final ArchitectureAnalyzer analyzer;

  WorkspaceStatus _status = WorkspaceStatus.empty;
  ProjectGraph? _graph;
  GraphAnalysis? _analysis;
  AppFailure? _failure;
  String? _lastRootPath;
  int _requestToken = 0;

  WorkspaceStatus get status => _status;

  ProjectGraph? get graph => _graph;

  GraphAnalysis? get analysis => _analysis;

  AppFailure? get failure => _failure;

  String? get lastRootPath => _lastRootPath;

  bool get isBusy => _status == WorkspaceStatus.scanning;

  bool get hasGraph => _graph != null && _analysis != null;

  Future<void> openProject(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      _fail(
        const AppFailure(
          message: 'Не выбран каталог проекта.',
          code: FailureCode.validation,
        ),
      );
      return;
    }

    final token = ++_requestToken;
    _lastRootPath = trimmed;
    _status = WorkspaceStatus.scanning;
    _failure = null;
    notifyListeners();

    try {
      final graph = await scanner.scan(trimmed);
      if (token != _requestToken) return;
      _graph = graph;
      _analysis = analyzer.analyze(graph);
      _status = WorkspaceStatus.ready;
      _failure = null;
    } on AppFailure catch (failure) {
      if (token != _requestToken) return;
      _fail(failure);
      return;
    }
    notifyListeners();
  }

  Future<void> rescan() async {
    final path = _lastRootPath;
    if (path == null || path.isEmpty) return;
    await openProject(path);
  }

  void clear() {
    _requestToken++;
    _graph = null;
    _analysis = null;
    _failure = null;
    _status = WorkspaceStatus.empty;
    notifyListeners();
  }

  void _fail(AppFailure failure) {
    _graph = null;
    _analysis = null;
    _status = WorkspaceStatus.failure;
    _failure = failure;
    notifyListeners();
  }
}
