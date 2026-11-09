import 'app_failure.dart';

/// Результат операции: либо значение, либо доменная ошибка.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final failure) => failure,
  };

  R fold<R>(
    R Function(T value) onSuccess,
    R Function(AppFailure failure) onFailure,
  ) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Failure<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;
}
