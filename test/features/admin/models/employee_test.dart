import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('Employee', () {
    test('fromJson은 사원 정보 전체를 매핑한다', () {
      final emp = Employee.fromJson(fixtureJson('admin/employee.json'));

      expect(emp.employeeId, 5);
      expect(emp.employeeNumber, 'A0001');
      expect(emp.name, '홍길동');
      expect(emp.position, '과장');
      expect(emp.teamList, ['SI사업팀', 'BI사업팀']);
      expect(emp.hireDate, '2020-01-01');
      expect(emp.fireDate, isNull);
      expect(emp.role, 'EMPLOYEE');
      expect(emp.currTotalLeaveDays, 15.0);
      expect(emp.remainingLeaveDays, 11.5);
      expect(emp.approverName, '김결재');
      expect(emp.isRegisted, isTrue);
    });

    test('선택 필드가 없으면 기본값으로 채운다', () {
      final emp = Employee.fromJson(const {
        'employeeNumber': 'A0009',
        'name': '최신규',
      });

      expect(emp.employeeId, isNull);
      expect(emp.position, '');
      expect(emp.department, '');
      expect(emp.team, '');
      expect(emp.teamList, isNull);
      expect(emp.currTotalLeaveDays, 0.0);
      expect(emp.remainingLeaveDays, 0.0);
      expect(emp.approverNumber, '');
      expect(emp.isRegisted, isFalse);
    });

    test('isCeo - 사장과 대표이사 표기를 모두 대표 직급으로 인정한다', () {
      Employee withPosition(String position) => Employee.fromJson(
          fixtureJson('admin/employee.json')..['position'] = position);

      expect(withPosition('사장').isCeo, isTrue);
      expect(withPosition('대표이사').isCeo, isTrue);
      expect(withPosition('과장').isCeo, isFalse);
      expect(withPosition('이사').isCeo, isFalse);
    });

    test('copyWith는 지정한 필드만 바꾸고 나머지를 유지한다', () {
      final emp = Employee.fromJson(fixtureJson('admin/employee.json'));
      final updated = emp.copyWith(email: 'new@example.com');

      expect(updated.email, 'new@example.com');
      expect(updated.employeeNumber, emp.employeeNumber);
      expect(updated.name, emp.name);
      expect(updated.remainingLeaveDays, emp.remainingLeaveDays);
      expect(updated.approverName, emp.approverName);
    });
  });
}
