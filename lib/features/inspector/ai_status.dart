class AiStatus {
  const AiStatus({
    required this.isOnline,
    required this.model,
    required this.availableModels,
    required this.latency,
    this.error,
  });

  const AiStatus.offline({this.error})
    : isOnline = false,
      model = '',
      availableModels = const [],
      latency = Duration.zero;

  final bool isOnline;
  final String model;
  final List<String> availableModels;
  final Duration latency;
  final String? error;

  bool get hasModel =>
      availableModels.isEmpty ||
      availableModels.any(
        (item) =>
            item == model || item.split(':').first == model.split(':').first,
      );
}
