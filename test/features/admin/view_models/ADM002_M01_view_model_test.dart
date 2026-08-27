import 'package:annual_leave_frontend/features/admin/view_models/ADM002_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canAssignAdminRole - 관리자 역할 부여 규칙', () {
    test('사장이면서 관리자인 접속자만 부여할 수 있다', () {
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUserPosition: '사장', currentUserRole: 'ADMIN'),
        isTrue,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUserPosition: '사장', currentUserRole: 'EMPLOYEE'),
        isFalse,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUserPosition: '과장', currentUserRole: 'ADMIN'),
        isFalse,
      );
    });
  });
}
