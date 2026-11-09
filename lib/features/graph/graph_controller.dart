import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:codegraph/features/analysis/architecture_issue.dart';
import 'package:codegraph/features/analysis/graph_analysis.dart';
import 'package:codegraph/features/project_scan/architecture_layer.dart';
import 'package:codegraph/features/project_scan/dependency_edge.dart';
import 'package:codegraph/features/project_scan/project_graph.dart';
import 'package:codegraph/features/project_scan/source_file.dart';
import 'package:codegraph/features/project_scan/workspace_controller.dart';
import 'package:codegraph/features/graph/layered_layout.dart';
import 'package:codegraph/features/graph/viewport_clamp.dart';

/// Роль файла относительно выбранного узла.
enum GraphRelation {
  /// Выбранный файл импортирует этот файл.
  imports,

  /// Этот файл импортирует выбранный.
  importer,

  /// Файлы зависят друг от друга в обе стороны.
  both,
}

class GraphController extends ChangeNotifier {
  GraphController(this._workspace) {
    _workspace.addListener(_onWorkspaceChanged);
    _syncWorkspace();
  }

  final WorkspaceController _workspace;

  TransformationController? _transformationController;

  Size _viewportSize = Size.zero;
  Size _contentSize = Size.zero;
  Map<String, Offset> _nodePositions = const {};
  bool _isClamping = false;
  bool _disposed = false;

  /// Жёсткие границы масштаба. Нижняя граница дополнительно поднимается до
  /// масштаба вписывания: иначе граф можно уменьшить до неразличимой точки,
  /// и экран выглядит пустым.
  static const double _hardMinZoom = 0.05;
  static const double _maxZoom = 4.0;

  /// В режиме фокуса не приближаем одинокую карточку на весь экран.
  static const double _maxFocusScale = 1.2;

  Offset get _viewportCenter =>
      Offset(_viewportSize.width / 2, _viewportSize.height / 2);

  /// Полный прямоугольник сцены.
  Rect get _fullRect => Offset.zero & _contentSize;

  /// Отступы, которые перекрывают панели поверх графа: тулбар сверху и
  /// подсказка снизу. В режиме фокуса сверху добавляется плашка со счётчиками.
  static const EdgeInsets _fitInsets = EdgeInsets.fromLTRB(12, 64, 12, 30);
  static const EdgeInsets _focusInsets = EdgeInsets.fromLTRB(12, 104, 12, 30);

  EdgeInsets get _activeInsets =>
      _selectedNodeId == null ? _fitInsets : _focusInsets;

  /// Прямоугольник узлов, которые сейчас реально показаны.
  Rect? get _displayedBounds {
    if (_selectedNodeId == null) return null;
    return _boundsOf(focusedNodeIds);
  }

  Rect? _boundsOf(Iterable<String> nodeIds) {
    Rect? rect;
    for (final id in nodeIds) {
      final position = _nodePositions[id];
      if (position == null) continue;
      final nodeRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        kNodeWidth,
        kNodeHeight,
      );
      rect = rect == null ? nodeRect : rect.expandToInclude(nodeRect);
    }
    return rect;
  }

  /// Масштаб, при котором [rect] помещается в свободную область.
  double _fitScaleFor(Rect rect) {
    if (rect.isEmpty || _viewportSize.isEmpty) return _hardMinZoom;
    final insets = _activeInsets;
    final availableWidth = math.max(
      1.0,
      _viewportSize.width - insets.horizontal,
    );
    final availableHeight = math.max(
      1.0,
      _viewportSize.height - insets.vertical,
    );
    return math.min(
          availableWidth / rect.width,
          availableHeight / rect.height,
        ) *
        0.95;
  }

  /// Итоговый масштаб вписывания: в фокусе ограничен, чтобы одна карточка
  /// не занимала весь экран.
  double _targetScaleFor(Rect rect) {
    final fit = _fitScaleFor(rect);
    final scale = _selectedNodeId == null ? fit : math.min(fit, _maxFocusScale);
    return scale.clamp(_hardMinZoom, _maxZoom).toDouble();
  }

  /// Минимальный допустимый масштаб: чуть меньше вписывания, но не точка.
  double get _minScale {
    final rect = _displayedBounds ?? _fullRect;
    return math.max(_hardMinZoom, math.min(1.0, _targetScaleFor(rect)) * 0.9);
  }

  TransformationController get transformationController =>
      _transformationController ??= _createTransformationController();

  TransformationController _createTransformationController() {
    return TransformationController()..addListener(_onTransformChanged);
  }

  /// Размер видимой области графа (без панелей).
  Size get viewportSize => _viewportSize;

  /// Реальный размер сцены, который вернул алгоритм раскладки.
  Size get contentSize => _contentSize;

  /// Размер видимой области графа (без панелей).
  void updateViewport(Size size) {
    if (size == _viewportSize) return;
    _viewportSize = size;
    // Панель инспектора может появиться после выбора узла и сузить вьюпорт.
    // В этом случае сцену нужно вернуть в видимую область.
    _scheduleTransformCheck();
  }

  /// Сообщает контроллеру параметры новой сцены: размер и координаты узлов.
  ///
  /// Вызывается из раскладки при каждом построении сцены, поэтому здесь нет
  /// `notifyListeners`: иначе сборка виджетов запускала бы новую сборку.
  void updateScene(Size size, Map<String, Offset> positions) {
    _contentSize = size;
    _nodePositions = positions;
    _scheduleTransformCheck();
  }

  /// Центр узла в координатах сцены (для перехода к узлу).
  Offset? nodeCenter(String nodeId) {
    final position = _nodePositions[nodeId];
    if (position == null) return null;
    return position + const Offset(kNodeWidth / 2, kNodeHeight / 2);
  }

  /// Пересчитывает ограничения трансформации после завершения кадра:
  /// менять матрицу во время раскладки нельзя.
  void _scheduleTransformCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _transformationController == null) return;
      _onTransformChanged();
    });
  }

  /// Сдвигает сцену на [delta] в экранных пикселях.
  ///
  /// Используется тестами и программным панорамированием; жест мыши
  /// обрабатывает сам `InteractiveViewer`.
  void panBy(Offset delta) {
    if (delta == Offset.zero) return;
    final controller = transformationController;
    controller.value = controller.value.clone()
      ..storage[12] += delta.dx
      ..storage[13] += delta.dy;
  }

  /// Сбрасывает вид перед построением новой сцены (смена проекта/фильтров).
  void resetScene() {
    _contentSize = Size.zero;
    _nodePositions = const {};
    _transformationController?.value = Matrix4.identity();
  }

  /// Не даёт панорамированию увести граф за пределы экрана и не позволяет
  /// уменьшить его до неразличимого размера.
  void _onTransformChanged() {
    if (_isClamping) return;
    final controller = _transformationController;
    if (controller == null) return;

    var matrix = controller.value;
    final scale = transformScale(matrix);
    if (scale.isFinite && scale > 0) {
      final target = scale.clamp(_minScale, _maxZoom).toDouble();
      if ((target - scale).abs() > 0.0001) {
        matrix = scaleTransformAround(matrix, target, _viewportCenter);
      }
    }

    var clamped = clampTransformToViewport(
      matrix,
      content: _contentSize,
      viewport: _viewportSize,
    );
    clamped = _keepNodeInView(clamped);

    if (identical(clamped, controller.value)) return;

    _isClamping = true;
    controller.value = clamped;
    _isClamping = false;
  }

  /// Страховка от «пустого экрана»: если в центральной части вьюпорта нет
  /// ни одного узла (например, после сильного панорамирования за границу или
  /// зума в промежуток между колонками), сцена сдвигается к ближайшему узлу.
  ///
  /// Недостаточно проверять сам факт пересечения с вьюпортом: после
  /// панорамирования от графа может остаться полоска в 96 px у края, и экран
  /// выглядит пустым. Поэтому узел должен попадать в безопасную зону —
  /// центральные 70% вьюпорта.
  Matrix4 _keepNodeInView(Matrix4 matrix) {
    if (_nodePositions.isEmpty || _viewportSize.isEmpty) return matrix;
    final scale = transformScale(matrix);
    if (!scale.isFinite || scale <= 0) return matrix;

    final tx = matrix.storage[12];
    final ty = matrix.storage[13];
    final visible = Rect.fromLTRB(
      -tx / scale,
      -ty / scale,
      (_viewportSize.width - tx) / scale,
      (_viewportSize.height - ty) / scale,
    );
    final safe = Rect.fromLTRB(
      visible.left + visible.width * 0.15,
      visible.top + visible.height * 0.15,
      visible.right - visible.width * 0.15,
      visible.bottom - visible.height * 0.15,
    );

    var nearest = Offset.zero;
    var nearestDistance = double.infinity;
    final positions = _selectedNodeId == null
        ? _nodePositions.values
        : focusedNodeIds.map((id) => _nodePositions[id]).whereType<Offset>();
    for (final position in positions) {
      final nodeRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        kNodeWidth,
        kNodeHeight,
      );
      if (nodeRect.overlaps(safe)) return matrix;

      final center = position + const Offset(kNodeWidth / 2, kNodeHeight / 2);
      final distance = (center - visible.center).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = center;
      }
    }

    if (!nearestDistance.isFinite) return matrix;

    final translation = _viewportCenter - nearest * scale;
    return matrix.clone()
      ..storage[12] = translation.dx
      ..storage[13] = translation.dy;
  }

  ProjectGraph? _graph;
  GraphAnalysis? _analysis;
  int _revision = 0;

  String? _selectedNodeId;
  String? _activeIssueId;
  final Set<ArchitectureLayer> _hiddenLayers = {};
  final Set<String> _resolvedIssueIds = {};
  ArchitectureLayer? _soloLayer;
  bool _issuesOnly = false;

  ProjectGraph? get graph => _graph;

  GraphAnalysis? get analysis => _analysis;

  SourceFile? get selectedFile {
    final id = _selectedNodeId;
    if (id == null) return null;
    return _graph?.fileById(id);
  }

  String? get selectedNodeId => _selectedNodeId;

  String? get activeIssueId => _activeIssueId;

  bool get issuesOnly => _issuesOnly;

  Set<ArchitectureLayer> get hiddenLayers => Set.unmodifiable(_hiddenLayers);

  /// Слой, выбранный для одиночного показа, либо `null` — видны все слои.
  ArchitectureLayer? get soloLayer => _soloLayer;

  Set<String> get resolvedIssueIds => Set.unmodifiable(_resolvedIssueIds);

  bool isLayerSolo(ArchitectureLayer layer) => _soloLayer == layer;

  bool isIssueResolved(String issueId) => _resolvedIssueIds.contains(issueId);

  /// Аномалии, которые пользователь ещё не отметил проверенными.
  List<ArchitectureIssue> get unresolvedIssues {
    final issues = _analysis?.issues ?? const <ArchitectureIssue>[];
    return issues
        .where((issue) => !_resolvedIssueIds.contains(issue.id))
        .toList(growable: false);
  }

  List<ArchitectureIssue> unresolvedIssuesForNode(String nodeId) {
    return unresolvedIssues
        .where((issue) => issue.nodeIds.contains(nodeId))
        .toList(growable: false);
  }

  bool hasUnresolvedIssues(String nodeId) {
    final issues = _analysis?.issuesForNode(nodeId) ?? const [];
    return issues.any((issue) => !_resolvedIssueIds.contains(issue.id));
  }

  int get unresolvedIssueCount => unresolvedIssues.length;

  /// Индекс здоровья пересчитывается без проверенных аномалий.
  int get adjustedHealthScore {
    final graph = _graph;
    if (graph == null || graph.fileCount == 0) return 0;

    var cycles = 0;
    var violations = 0;
    var isolated = 0;
    var coupling = 0;
    for (final issue in unresolvedIssues) {
      switch (issue.kind) {
        case IssueKind.circularDependency:
          cycles++;
        case IssueKind.layerViolation:
          violations++;
        case IssueKind.isolatedFile:
          isolated++;
        case IssueKind.highCoupling:
          coupling++;
      }
    }

    final penalty = cycles * 12 + violations * 6 + isolated * 4 + coupling * 2;
    return (100 - penalty).clamp(0, 100);
  }

  Set<String> get unresolvedCycleEdgeIds =>
      _edgeIdsFor(IssueKind.circularDependency);

  Set<String> get unresolvedViolationEdgeIds =>
      _edgeIdsFor(IssueKind.layerViolation);

  Set<String> _edgeIdsFor(IssueKind kind) {
    final result = <String>{};
    for (final issue in unresolvedIssues) {
      if (issue.kind == kind) result.addAll(issue.edgeKeys);
    }
    return result;
  }

  List<SourceFile> get visibleFiles {
    final graph = _graph;
    if (graph == null) return const [];
    return graph.files
        .where((file) {
          if (_soloLayer != null && file.layer != _soloLayer) return false;
          if (_hiddenLayers.contains(file.layer)) return false;
          if (_issuesOnly && !hasUnresolvedIssues(file.id)) return false;
          return true;
        })
        .toList(growable: false);
  }

  Set<String> get visibleNodeIds => visibleFiles.map((file) => file.id).toSet();

  /// Режим фокуса: выбранный файл и его прямые связи, остальные скрыты.
  bool get isFocusMode => _selectedNodeId != null;

  /// Файлы, которые импортирует выбранный узел (с учётом фильтров).
  List<SourceFile> get selectedDependencies {
    final selected = _selectedNodeId;
    if (selected == null) return const [];
    final visible = visibleNodeIds;
    return (_graph?.dependenciesOf(selected) ?? const [])
        .where((file) => visible.contains(file.id))
        .toList(growable: false);
  }

  /// Файлы, которые импортируют выбранный узел (с учётом фильтров).
  List<SourceFile> get selectedDependents {
    final selected = _selectedNodeId;
    if (selected == null) return const [];
    final visible = visibleNodeIds;
    return (_graph?.dependentsOf(selected) ?? const [])
        .where((file) => visible.contains(file.id))
        .toList(growable: false);
  }

  /// Идентификаторы узлов, которые видны в текущем режиме.
  Set<String> get focusedNodeIds {
    final selected = _selectedNodeId;
    if (selected == null) return visibleNodeIds;
    return {
      selected,
      ...selectedDependencies.map((file) => file.id),
      ...selectedDependents.map((file) => file.id),
    };
  }

  /// Файлы, которые нужно нарисовать: в фокусе — только выбранный и соседи.
  List<SourceFile> get displayedFiles {
    final selected = _selectedNodeId;
    if (selected == null) return visibleFiles;
    final ids = focusedNodeIds;
    return visibleFiles
        .where((file) => ids.contains(file.id))
        .toList(growable: false);
  }

  /// Рёбра, которые нужно нарисовать. В фокусе — только связи выбранного узла.
  List<DependencyEdge> get displayedEdges {
    final graph = _graph;
    if (graph == null) return const [];
    final selected = _selectedNodeId;
    if (selected == null) return graph.edges;
    final ids = focusedNodeIds;
    return graph.edges
        .where(
          (edge) =>
              ids.contains(edge.fromId) &&
              ids.contains(edge.toId) &&
              (edge.fromId == selected || edge.toId == selected),
        )
        .toList(growable: false);
  }

  String get structureSignature {
    final hidden = _hiddenLayers.map((layer) => layer.name).toList()..sort();
    final resolved = _resolvedIssueIds.toList()..sort();
    return '$_revision|${hidden.join(',')}|${_soloLayer?.name ?? ''}'
        '|$_issuesOnly|${resolved.join(',')}';
  }

  bool get hasVisibleFiles => visibleFiles.isNotEmpty;

  bool isLayerVisible(ArchitectureLayer layer) =>
      !_hiddenLayers.contains(layer);

  bool isSelected(String nodeId) => _selectedNodeId == nodeId;

  bool isNeighbor(String nodeId) => relationTo(nodeId) != null;

  /// Роль файла относительно выбранного узла.
  GraphRelation? relationTo(String nodeId) {
    final selected = _selectedNodeId;
    if (selected == null || selected == nodeId) return null;
    return _relation(selected, nodeId);
  }

  /// Роль ребра относительно выбранного узла.
  GraphRelation? edgeRelation(DependencyEdge edge) {
    final selected = _selectedNodeId;
    if (selected == null) return null;
    final outgoing = edge.fromId == selected;
    final incoming = edge.toId == selected;
    if (outgoing && incoming) return GraphRelation.both;
    if (outgoing) return GraphRelation.imports;
    if (incoming) return GraphRelation.importer;
    return null;
  }

  GraphRelation? _relation(String selected, String nodeId) {
    final graph = _graph;
    if (graph == null) return null;
    final outgoing = graph
        .outgoingEdges(selected)
        .any((edge) => edge.toId == nodeId);
    final incoming = graph
        .incomingEdges(selected)
        .any((edge) => edge.fromId == nodeId);
    if (outgoing && incoming) return GraphRelation.both;
    if (outgoing) return GraphRelation.imports;
    if (incoming) return GraphRelation.importer;
    return null;
  }

  ArchitectureIssue? activeIssue(String nodeId) {
    final issueId = _activeIssueId;
    if (issueId == null) return null;
    for (final issue in _analysis?.issuesForNode(nodeId) ?? const []) {
      if (issue.id == issueId) return issue;
    }
    return null;
  }

  void selectNode(String? nodeId) {
    if (nodeId != null && !visibleNodeIds.contains(nodeId)) return;
    if (_selectedNodeId == nodeId) return;
    _selectedNodeId = nodeId;
    _activeIssueId = null;
    notifyListeners();
    _scheduleViewForSelection(nodeId);
  }

  void selectIssue(ArchitectureIssue issue) {
    final nodeId = issue.primaryNodeId;
    if (nodeId == null) return;
    if (!visibleNodeIds.contains(nodeId)) {
      _hiddenLayers.remove(_graph?.fileById(nodeId)?.layer);
      _soloLayer = null;
      _issuesOnly = false;
    }
    _selectedNodeId = nodeId;
    _activeIssueId = issue.id;
    notifyListeners();
    _scheduleViewForSelection(nodeId);
  }

  void _scheduleViewForSelection(String? nodeId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _selectedNodeId != nodeId) return;
      if (nodeId == null) {
        zoomToFit();
      } else {
        focusSelection();
      }
    });
  }

  /// Вписывает в экран выбранный узел вместе с его связями.
  void focusSelection() {
    final selected = _selectedNodeId;
    if (selected == null) {
      zoomToFit();
      return;
    }
    final rect = _displayedBounds;
    if (rect == null) {
      focusNode(selected);
      return;
    }
    _fitRect(rect);
  }

  /// Центрирует узел во вьюпорте и поднимает масштаб до читаемого.
  ///
  /// Переход не зависит от внутренних анимаций пакета: матрица вычисляется
  /// напрямую из координат раскладки, поэтому узел не может «уехать» за экран.
  void focusNode(String nodeId) {
    final center = nodeCenter(nodeId);
    final controller = _transformationController;
    if (center == null || controller == null) return;
    if (_viewportSize.isEmpty) return;

    final current = transformScale(controller.value);
    const readable = 0.7;
    final targetScale =
        (current.isFinite && current >= readable ? current : readable)
            .clamp(_minScale, _maxZoom)
            .toDouble();

    final translation = _viewportCenter - center * targetScale;
    controller.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, targetScale, 1);
  }

  void toggleLayer(ArchitectureLayer layer) {
    if (!_hiddenLayers.remove(layer)) {
      _hiddenLayers.add(layer);
    }
    _ensureSelectionVisible();
    notifyListeners();
  }

  /// Клик по слою показывает только его; повторный клик возвращает все слои.
  void toggleSoloLayer(ArchitectureLayer layer) {
    _soloLayer = _soloLayer == layer ? null : layer;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void toggleIssueResolved(String issueId) {
    if (!_resolvedIssueIds.remove(issueId)) {
      _resolvedIssueIds.add(issueId);
    }
    notifyListeners();
  }

  void toggleIssuesOnly() {
    _issuesOnly = !_issuesOnly;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void clearFilters() {
    if (_hiddenLayers.isEmpty && !_issuesOnly && _soloLayer == null) return;
    _hiddenLayers.clear();
    _soloLayer = null;
    _issuesOnly = false;
    _ensureSelectionVisible();
    notifyListeners();
  }

  void zoomIn() => _zoom(1.16);

  void zoomOut() => _zoom(1 / 1.16);

  /// Вписывает в экран весь граф или, в режиме фокуса, только его окрестность.
  void zoomToFit() {
    final rect = _displayedBounds ?? _fullRect;
    if (rect.isEmpty) return;
    _fitRect(rect);
  }

  void _fitRect(Rect rect) {
    if (rect.isEmpty || _viewportSize.isEmpty) return;
    final controller = transformationController;
    final insets = _activeInsets;
    final availableWidth = math.max(
      1.0,
      _viewportSize.width - insets.horizontal,
    );
    final availableHeight = math.max(
      1.0,
      _viewportSize.height - insets.vertical,
    );
    final scale = _targetScaleFor(rect);
    final translation = Offset(
      insets.left +
          (availableWidth - rect.width * scale) / 2 -
          rect.left * scale,
      insets.top +
          (availableHeight - rect.height * scale) / 2 -
          rect.top * scale,
    );

    controller.value = Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  /// Раскладка детерминирована, поэтому «перестроение» возвращает граф
  /// в видимую область, а не создаёт новые координаты.
  void recalculateLayout() => zoomToFit();

  void _zoom(double factor) {
    final controller = transformationController;
    final current = transformScale(controller.value);
    if (!current.isFinite || current <= 0) return;

    // Масштабируем вокруг центра вьюпорта: иначе сцена «уезжает» в угол,
    // а при сильном уменьшении превращается в незаметную точку.
    final target = (current * factor).clamp(_minScale, _maxZoom).toDouble();
    if ((target - current).abs() < 0.0001) return;

    controller.value = scaleTransformAround(
      controller.value,
      target,
      _viewportCenter,
    );
  }

  void _ensureSelectionVisible() {
    final selected = _selectedNodeId;
    if (selected == null) return;
    if (!visibleNodeIds.contains(selected)) {
      _selectedNodeId = null;
      _activeIssueId = null;
    }
  }

  void _onWorkspaceChanged() {
    if (identical(_graph, _workspace.graph)) return;
    _syncWorkspace();
    notifyListeners();
  }

  void _syncWorkspace() {
    _graph = _workspace.graph;
    _analysis = _workspace.analysis;
    _revision++;
    _selectedNodeId = null;
    _activeIssueId = null;
    _hiddenLayers.clear();
    _resolvedIssueIds.clear();
    _soloLayer = null;
    _issuesOnly = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _workspace.removeListener(_onWorkspaceChanged);
    _transformationController?.removeListener(_onTransformChanged);
    _transformationController?.dispose();
    super.dispose();
  }
}
