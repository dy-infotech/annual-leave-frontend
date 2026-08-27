/// 데이터 계층에서 발생한 오류를 표현하는 공통 모델.
///
/// Repository가 DioException 등 저수준 예외를 잡아 이 타입으로 변환해
/// 반환하며, 화면에는 [message]를 그대로 노출할 수 있어야 한다.
class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}
