// signup_manage_screen(관리자의 직원 등록)에서만 쓰이는 enum이라 이 feature 하위로 이동.
enum RoleType {

  admin('ADMIN', '관리자'),
  employee('EMPLOYEE', '멤버');

  final String code;
  final String label;
  const RoleType(this.code, this.label);
}
