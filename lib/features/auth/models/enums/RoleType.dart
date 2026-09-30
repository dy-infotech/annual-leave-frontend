enum RoleType {

  admin('ADMIN', '관리자'),
  employee('EMPLOYEE', '멤버');

  final String code;
  final String label;
  const RoleType(this.code, this.label);
}