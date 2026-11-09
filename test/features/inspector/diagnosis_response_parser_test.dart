import 'package:codegraph/features/inspector/diagnosis_response_parser.dart';
import 'package:codegraph/features/inspector/ai_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = DiagnosisResponseParser();

  AiDiagnosis parse(String raw) => parser.parse(
    rawResponse: raw,
    nodeId: 'lib/main.dart',
    model: 'qwen2.5-coder',
    latency: const Duration(milliseconds: 640),
  );

  test('разбирает JSON в markdown-обёртке', () {
    final result = parse('''
```json
{
  "verdict": "violations",
  "severity": "high",
  "summary": "Есть обратная зависимость.",
  "recommendations": ["Вынести интерфейс", "Убрать импорт data"]
}
```
''');

    expect(result.verdict, DiagnosisVerdict.violations);
    expect(result.severity, DiagnosisSeverity.high);
    expect(result.summary, 'Есть обратная зависимость.');
    expect(result.recommendations, hasLength(2));
    expect(result.source, DiagnosisSource.ollama);
    expect(result.latency, const Duration(milliseconds: 640));
  });

  test('понимает русский вердикт и строковые рекомендации', () {
    final result = parse(
      '{"verdict":"Есть критические нарушения","severity":"высокий",'
      '"summary":"Цикл","recommendations":"1. Разорвать цикл\\n2. Добавить тест"}',
    );

    expect(result.verdict, DiagnosisVerdict.violations);
    expect(result.severity, DiagnosisSeverity.high);
    expect(result.recommendations, ['Разорвать цикл', 'Добавить тест']);
  });

  test('распознаёт отсутствие ошибок', () {
    final result = parse(
      '{"verdict":"ok","severity":"low","summary":"Чисто",'
      '"recommendations":[]}',
    );
    expect(result.verdict, DiagnosisVerdict.clear);
    expect(result.isClear, isTrue);
  });

  test('возвращает unknown для невалидного ответа', () {
    final result = parse('Модель не смогла ответить.');
    expect(result.verdict, DiagnosisVerdict.unknown);
    expect(result.summary, 'Модель не смогла ответить.');
    expect(result.recommendations, isEmpty);
  });
}
