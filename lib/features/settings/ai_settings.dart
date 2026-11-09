class AiSettings {
  const AiSettings({
    required this.baseUrl,
    required this.model,
    required this.timeout,
  });

  static const AiSettings defaults = AiSettings(
    baseUrl: 'http://localhost:11434',
    model: 'qwen2.5-coder',
    timeout: Duration(seconds: 45),
  );

  final String baseUrl;
  final String model;
  final Duration timeout;

  String get normalizedBaseUrl {
    var value = baseUrl.trim();
    if (value.isEmpty) return defaults.baseUrl;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  AiSettings copyWith({String? baseUrl, String? model, Duration? timeout}) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSettings &&
          other.baseUrl == baseUrl &&
          other.model == model &&
          other.timeout == timeout;

  @override
  int get hashCode => Object.hash(baseUrl, model, timeout);
}
