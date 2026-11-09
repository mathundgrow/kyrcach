enum IssueKind {
  isolatedFile,
  circularDependency,
  layerViolation,
  highCoupling,
}

extension IssueKindInfo on IssueKind {
  String get title => switch (this) {
    IssueKind.isolatedFile => 'Изолированный файл',
    IssueKind.circularDependency => 'Циклическая зависимость',
    IssueKind.layerViolation => 'Нарушение слоёв',
    IssueKind.highCoupling => 'Высокая связанность',
  };

  String get shortLabel => switch (this) {
    IssueKind.isolatedFile => 'Dead code',
    IssueKind.circularDependency => 'Cycle',
    IssueKind.layerViolation => 'Layers',
    IssueKind.highCoupling => 'Coupling',
  };
}

enum IssueSeverity { critical, warning, info }

extension IssueSeverityInfo on IssueSeverity {
  String get title => switch (this) {
    IssueSeverity.critical => 'Критично',
    IssueSeverity.warning => 'Предупреждение',
    IssueSeverity.info => 'Информация',
  };

  int get rank => switch (this) {
    IssueSeverity.critical => 0,
    IssueSeverity.warning => 1,
    IssueSeverity.info => 2,
  };
}

class ArchitectureIssue {
  const ArchitectureIssue({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.description,
    required this.nodeIds,
    this.edgeKeys = const {},
    this.metric,
  });

  final String id;
  final IssueKind kind;
  final IssueSeverity severity;
  final String title;
  final String description;
  final List<String> nodeIds;
  final Set<String> edgeKeys;

  /// Числовое значение аномалии: число импортов, размер цикла и т. п.
  final int? metric;

  String? get primaryNodeId => nodeIds.isEmpty ? null : nodeIds.first;
}
