import 'package:annual_leave_frontend/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginRequest', () {
    test('serializes credentials', () {
      final request = LoginRequest(
        employeeNumber: 'EMP-001',
        password: 'secret',
      );

      expect(request.toJson(), {
        'employeeNumber': 'EMP-001',
        'password': 'secret',
      });
    });
  });

  group('LoginResponse', () {
    test('deserializes an admin response', () {
      final response = LoginResponse.fromJson({
        'token': 'token',
        'employeeId': 7,
        'name': '홍길동',
        'role': 'ADMIN',
      });

      expect(response.token, 'token');
      expect(response.employeeId, 7);
      expect(response.name, '홍길동');
      expect(response.role, 'ADMIN');
      expect(response.isAdmin, isTrue);
    });

    test('identifies non-admin roles', () {
      final response = LoginResponse.fromJson({
        'token': 'token',
        'employeeId': 8,
        'name': '김직원',
        'role': 'EMPLOYEE',
      });

      expect(response.isAdmin, isFalse);
    });
  });

  group('SignUpRequest', () {
    test('serializes credentials', () {
      final request = SignUpRequest(
        employeeNumber: 'EMP-002',
        password: 'password',
      );

      expect(request.toJson(), {
        'employeeNumber': 'EMP-002',
        'password': 'password',
      });
    });
  });
}
