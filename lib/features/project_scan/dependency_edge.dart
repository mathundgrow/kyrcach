/// тип зависимости
enum DependencyKind {
  local('Локальный импорт'),
  package('Пакет проекта');

  const DependencyKind(this.title);

  final String title;
}

/// тип директивы
enum ImportDirective {
  import('import'),
  export('export');

  const ImportDirective(this.keyword);

  final String keyword;
}

/// Направленное ребро графа: файл [fromId] зависит от [toId].
class DependencyEdge {

  final String fromId;
  final String toId;
  final String uri;
  final DependencyKind kind;
  final ImportDirective directive;
  
  const DependencyEdge({
    required this.fromId,
    required this.toId,
    required this.uri,
    required this.kind,
    required this.directive,
  });


  String get id => '$fromId→$toId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyEdge && other.fromId == fromId && other.toId == toId;

  @override
  int get hashCode => Object.hash(fromId, toId);

  @override
  String toString() => 'DependencyEdge($fromId -> $toId)';
}
