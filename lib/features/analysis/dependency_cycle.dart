class DependencyCycle {
  const DependencyCycle(this.nodeIds);

  final List<String> nodeIds;

  int get length => nodeIds.length;

  String get signature => nodeIds.join('|');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DependencyCycle && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}
