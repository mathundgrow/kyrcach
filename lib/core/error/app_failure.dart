/// Доменный тип ошибки, не зависящий от Flutter и конкретной инфраструктуры.
enum FailureCode {
  validation,
  notFound,
  accessDenied,
  scan,
  aiUnavailable,
  aiInvalidResponse,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.message,
    this.code = FailureCode.unknown,
    this.details,
  });

  final String message;
  final FailureCode code;
  final String? details;

  @override
  String toString() => details == null ? message : '$message\n$details';
}
