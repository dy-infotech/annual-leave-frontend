import 'failure.dart';

/// 성공([Ok]) 또는 실패([Err])를 표현하는 Repository 공통 반환 타입.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final Failure failure;

  const Err(this.failure);
}
