import 'failure.dart';

/// 성공([Ok]) 또는 실패([Err])를 표현하는 반환 타입.
///
/// 현재는 SubmitLeaveRequest 유스케이스에서만 사용한다. Repository는 이 타입을 쓰지 않고
/// 예외(DioException)를 그대로 던진다.
sealed class Result<T> {
  const Result();

  /// 성공이면 [ok]에, 실패면 [err]에 결과를 넘겨 하나의 값으로 변환한다.
  R when<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final failure) => err(failure),
      };
}

/// 성공 결과. 반환값이 없는 작업은 `Ok(null)`을 쓴다.
final class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

/// 실패 결과. 화면에 보여줄 메시지는 [failure]의 message에 담긴다.
final class Err<T> extends Result<T> {
  final Failure failure;

  const Err(this.failure);
}
