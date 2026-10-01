/// 화면에 그대로 노출할 수 있는 오류 메시지를 담는 공통 모델.
///
/// 현재는 Result를 반환하는 유스케이스(SubmitLeaveRequest)에서만 사용한다.
/// 나머지 Repository는 DioException을 그대로 전파하며, ViewModel이 직접 메시지로 바꾼다.
class Failure {
  /// 사용자에게 그대로 보여줄 수 있는 메시지.
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}
