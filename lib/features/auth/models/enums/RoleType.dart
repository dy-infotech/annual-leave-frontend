/// 사용자 등록 승인 화면에서 선택하는 역할.
///
/// [code]는 서버와 주고받는 값이고, [label]은 화면에 보여주는 이름이다.
/// 로그인 후의 권한 판정(`AuthSession.isAdmin` 등)은 이 enum이 아니라 문자열 'ADMIN'을 직접 비교한다.
enum RoleType {

  admin('ADMIN', '관리자'),
  employee('EMPLOYEE', '멤버');

  final String code;
  final String label;
  const RoleType(this.code, this.label);
}
