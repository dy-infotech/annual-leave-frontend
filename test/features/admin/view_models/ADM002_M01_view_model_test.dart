import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM002_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  Employee user({required String position, required String role}) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['position'] = position
        ..['role'] = role);

  group('canAssignAdminRole - 관리자 역할 부여 규칙', () {
    test('대표 직급이면 PM 역할과 무관하게 관리자 역할을 부여할 수 있다', () {
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUser: user(position: '사장', role: 'ADMIN')),
        isTrue,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUser: user(position: '대표이사', role: 'ADMIN')),
        isTrue,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUser: user(position: '사장', role: 'EMPLOYEE')),
        isTrue,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(
            currentUser: user(position: '과장', role: 'ADMIN')),
        isFalse,
      );
      expect(
        SignupManageViewModel.canAssignAdminRole(currentUser: null),
        isFalse,
      );
    });
  });
}
