import 'package:annual_leave_frontend/models/employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Employee.fromJson', () {
    test('parses numeric leave values without losing fractions', () {
      final employee = Employee.fromJson({
        'employeeId': 7,
        'employeeNumber': 'A2026007',
        'name': '테스트',
        'position': '사원',
        'department': 'SI사업팀',
        'team': '플랫폼팀',
        'teamList': ['플랫폼팀'],
        'hireDate': '2026-01-02',
        'fireDate': null,
        'role': 'EMPLOYEE',
        'email': 'test@example.com',
        'currTotalLeaveDays': 15,
        'remainingLeaveDays': 7.5,
        'isRegisted': true,
      });

      expect(employee.employeeId, 7);
      expect(employee.currTotalLeaveDays, 15.0);
      expect(employee.remainingLeaveDays, 7.5);
      expect(employee.isRegisted, isTrue);
    });

    test('defaults missing leave totals and registration state safely', () {
      final employee = Employee.fromJson({
        'employeeNumber': 'A2026008',
        'name': '테스트2',
        'position': '사원',
        'department': 'SI사업팀',
        'team': '플랫폼팀',
      });

      expect(employee.currTotalLeaveDays, 0.0);
      expect(employee.remainingLeaveDays, 0.0);
      expect(employee.isRegisted, isFalse);
    });
  });
}
