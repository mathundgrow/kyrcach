import 'dart:convert';

import 'package:codegraph/features/inspector/ai_diagnosis.dart';

/// Разбирает ответ локальной модели, устойчиво к markdown-обёрткам и
/// частично невалидному JSON.
class DiagnosisResponseParser {
  const DiagnosisResponseParser();

  AiDiagnosis parse({
    required String rawResponse,
    required String nodeId,
    required String model,
    required Duration latency,
  }) {
    final payload = _extractJson(rawResponse);
    if (payload == null) {
      return AiDiagnosis(
        nodeId: nodeId,
        verdict: DiagnosisVerdict.unknown,
        summary: _trim(rawResponse),
        recommendations: const [],
        source: DiagnosisSource.ollama,
        model: model,
        latency: latency,
        createdAt: DateTime.now(),
      );
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return _fallback(rawResponse, nodeId, model, latency);
      }

      final json = Map<String, dynamic>.from(decoded);
      final verdict = _parseVerdict(json['verdict'] ?? json['status']);
      final severity = _parseSeverity(json['severity'] ?? json['risk']);
      final summary =
          (json['summary'] ?? json['analysis'] ?? json['answer'])
              ?.toString()
              .trim() ??
          '';
      final recommendations = _parseRecommendations(
        json['recommendations'] ?? json['steps'] ?? json['advice'],
      );

      return AiDiagnosis(
        nodeId: nodeId,
        verdict: verdict,
        summary: summary.isEmpty
            ? 'Модель не сформировала текстовое резюме.'
            : _trim(summary),
        recommendations: recommendations,
        source: DiagnosisSource.ollama,
        model: model,
        latency: latency,
        createdAt: DateTime.now(),
        severity: severity,
      );
    } on FormatException {
      return _fallback(rawResponse, nodeId, model, latency);
    }
  }

  AiDiagnosis _fallback(
    String raw,
    String nodeId,
    String model,
    Duration latency,
  ) {
    return AiDiagnosis(
      nodeId: nodeId,
      verdict: DiagnosisVerdict.unknown,
      summary: _trim(raw),
      recommendations: const [],
      source: DiagnosisSource.ollama,
      model: model,
      latency: latency,
      createdAt: DateTime.now(),
    );
  }

  String? _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewLine = text.indexOf('\n');
      if (firstNewLine != -1) text = text.substring(firstNewLine + 1);
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  DiagnosisVerdict _parseVerdict(dynamic value) {
    final text = value?.toString().toLowerCase().trim() ?? '';
    if (text.isEmpty) return DiagnosisVerdict.unknown;

    final clearMarkers = [
      'нет ошиб',
      'без ошиб',
      'no error',
      'no issue',
      'clean',
    ];
    if (clearMarkers.any(text.contains)) return DiagnosisVerdict.clear;

    if (text.contains('viol') ||
        text.contains('critical') ||
        text.contains('fail') ||
        text.contains('error') ||
        text.contains('ошиб') ||
        text.contains('наруш')) {
      return DiagnosisVerdict.violations;
    }

    if (text.contains('ok') ||
        text.contains('clear') ||
        text.contains('pass') ||
        text.contains('нет')) {
      return DiagnosisVerdict.clear;
    }

    return DiagnosisVerdict.unknown;
  }

  DiagnosisSeverity _parseSeverity(dynamic value) {
    final text = value?.toString().toLowerCase().trim() ?? '';
    if (text.contains('high') ||
        text.contains('critical') ||
        text.contains('высок')) {
      return DiagnosisSeverity.high;
    }
    if (text.contains('medium') ||
        text.contains('moderate') ||
        text.contains('средн')) {
      return DiagnosisSeverity.medium;
    }
    if (text.contains('low') ||
        text.contains('minor') ||
        text.contains('низк')) {
      return DiagnosisSeverity.low;
    }
    return DiagnosisSeverity.unknown;
  }

  List<String> _parseRecommendations(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(6)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'\n|(?<=\.)\s+(?=[А-ЯA-Z])'))
          .map(
            (item) => item.replaceFirst(RegExp(r'^[\-\d\.\)\s]+'), '').trim(),
          )
          .where((item) => item.isNotEmpty)
          .take(6)
          .toList(growable: false);
    }
    return const [];
  }

  String _trim(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 1600) return trimmed;
    return '${trimmed.substring(0, 1600)}…';
  }
}
