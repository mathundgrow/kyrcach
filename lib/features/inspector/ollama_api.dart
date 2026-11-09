import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:codegraph/core/error/app_failure.dart';
import 'package:codegraph/features/settings/ai_settings.dart';

class OllamaStatusResponse {
  const OllamaStatusResponse({required this.models, required this.latency});

  final List<String> models;
  final Duration latency;
}

/// Тонкая обёртка над HTTP-API локального сервера Ollama.
///
/// Любая проблема (нет соединения, таймаут, битый JSON, ошибка сервера)
/// превращается в [AppFailure] с понятным сообщением.
class OllamaApi {
  OllamaApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Список доступных моделей; заодно проверяет, что сервер живой.
  Future<OllamaStatusResponse> status(AiSettings settings) async {
    final stopwatch = Stopwatch()..start();
    final timeout = settings.timeout < const Duration(seconds: 6)
        ? settings.timeout
        : const Duration(seconds: 6);

    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('${settings.normalizedBaseUrl}/api/tags'))
          .timeout(timeout);
    } on TimeoutException {
      throw const AppFailure(
        message: 'Сервер Ollama не ответил вовремя. Проверьте, что он запущен.',
        details: 'Запустите: ollama serve',
        code: FailureCode.aiUnavailable,
      );
    } on http.ClientException catch (error) {
      throw AppFailure(
        message: 'Не удалось подключиться к Ollama.',
        details: '${error.message}\nЗапустите: ollama serve',
        code: FailureCode.aiUnavailable,
      );
    }
    stopwatch.stop();

    if (response.statusCode != 200) {
      throw AppFailure(
        message: 'Ollama ответила HTTP ${response.statusCode}.',
        details: 'HTTP ${response.statusCode}',
        code: FailureCode.aiUnavailable,
      );
    }

    final Object decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AppFailure(
        message: 'Ollama вернула некорректный JSON.',
        code: FailureCode.aiInvalidResponse,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure(
        message: 'Неожиданный ответ Ollama /api/tags.',
        code: FailureCode.aiInvalidResponse,
      );
    }

    final models = <String>[];
    final rawModels = decoded['models'];
    if (rawModels is List) {
      for (final item in rawModels) {
        if (item is Map) {
          final name = item['name'] ?? item['model'];
          if (name is String && name.isNotEmpty) models.add(name);
        }
      }
    }

    return OllamaStatusResponse(
      models: List.unmodifiable(models),
      latency: stopwatch.elapsed,
    );
  }

  /// Отправляет промпт модели и возвращает сырой текст ответа.
  Future<String> generate(AiSettings settings, String prompt) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${settings.normalizedBaseUrl}/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': settings.model,
              'prompt': prompt,
              'stream': false,
              'format': 'json',
              'options': {'temperature': 0.15, 'num_predict': 512},
            }),
          )
          .timeout(settings.timeout);
    } on TimeoutException {
      throw AppFailure(
        message:
            'Локальная модель не успела ответить за '
            '${settings.timeout.inSeconds} с. Увеличьте таймаут в настройках.',
        code: FailureCode.aiUnavailable,
      );
    } on http.ClientException catch (error) {
      throw AppFailure(
        message: 'Не удалось подключиться к Ollama.',
        details: '${error.message}\nЗапустите: ollama serve',
        code: FailureCode.aiUnavailable,
      );
    }

    if (response.statusCode != 200) {
      throw AppFailure(
        message:
            'Ollama ответила HTTP ${response.statusCode}. '
            'Проверьте, что модель «${settings.model}» загружена.',
        details: 'HTTP ${response.statusCode}',
        code: FailureCode.aiUnavailable,
      );
    }

    final Object decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AppFailure(
        message: 'Ollama вернула некорректный JSON.',
        code: FailureCode.aiInvalidResponse,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure(
        message: 'Неожиданный ответ Ollama /api/generate.',
        code: FailureCode.aiInvalidResponse,
      );
    }

    final error = decoded['error'];
    if (error is String && error.isNotEmpty) {
      throw AppFailure(
        message: 'Ollama: $error',
        code: FailureCode.aiUnavailable,
      );
    }

    final text = decoded['response'];
    if (text is! String || text.trim().isEmpty) {
      throw const AppFailure(
        message: 'Ollama вернула пустой ответ.',
        code: FailureCode.aiInvalidResponse,
      );
    }
    return text;
  }

  void dispose() => _client.close();
}
