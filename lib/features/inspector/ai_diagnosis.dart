enum DiagnosisVerdict { clear, violations, unknown }

extension DiagnosisVerdictInfo on DiagnosisVerdict {
  String get label => switch (this) {
    DiagnosisVerdict.clear => 'Ошибок нет',
    DiagnosisVerdict.violations => 'Есть нарушения',
    DiagnosisVerdict.unknown => 'Нужна проверка',
  };
}

enum DiagnosisSource { ollama, offline }

extension DiagnosisSourceInfo on DiagnosisSource {
  String get label => switch (this) {
    DiagnosisSource.ollama => 'Ollama',
    DiagnosisSource.offline => 'Offline-эвристика',
  };
}

enum DiagnosisSeverity { low, medium, high, unknown }

extension DiagnosisSeverityInfo on DiagnosisSeverity {
  String get label => switch (this) {
    DiagnosisSeverity.low => 'Низкий риск',
    DiagnosisSeverity.medium => 'Средний риск',
    DiagnosisSeverity.high => 'Высокий риск',
    DiagnosisSeverity.unknown => 'Риск не определён',
  };
}

class AiDiagnosis {
  const AiDiagnosis({
    required this.nodeId,
    required this.verdict,
    required this.summary,
    required this.recommendations,
    required this.source,
    required this.model,
    required this.latency,
    required this.createdAt,
    this.severity = DiagnosisSeverity.unknown,
    this.note,
  });

  final String nodeId;
  final DiagnosisVerdict verdict;
  final String summary;
  final List<String> recommendations;
  final DiagnosisSource source;
  final String model;
  final Duration latency;
  final DateTime createdAt;
  final DiagnosisSeverity severity;

  /// Пояснение, например причина перехода на офлайн-режим.
  final String? note;

  bool get isClear => verdict == DiagnosisVerdict.clear;

  AiDiagnosis copyWith({String? note}) {
    return AiDiagnosis(
      nodeId: nodeId,
      verdict: verdict,
      summary: summary,
      recommendations: recommendations,
      source: source,
      model: model,
      latency: latency,
      createdAt: createdAt,
      severity: severity,
      note: note ?? this.note,
    );
  }
}
