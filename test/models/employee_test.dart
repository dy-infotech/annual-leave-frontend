import 'package:annual_leave_frontend/models/employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deserializes all employee fields', () {
    final employee = Employee.fromJson({
      'employeeNumber': 'EMP-001',
      'name': '홍길동',
      'position': '대리',
      'department': '개발팀',
      'hireDate': '2024-01-02',
      'role': 'ADMIN',
    });

    expect(employee.employeeNumber, 'EMP-001');
    expect(employee.name, '홍길동');
    expect(employee.position, '대리');
    expect(employee.department, '개발팀');
    expect(employee.hireDate, '2024-01-02');
    expect(employee.role, 'ADMIN');
  });

  test('defaults missing position and department to empty strings', () {
    final employee = Employee.fromJson({
      'employeeNumber': 'EMP-002',
      'name': '김직원',
    });

    expect(employee.position, isEmpty);
    expect(employee.department, isEmpty);
    expect(employee.hireDate, isNull);
    expect(employee.role, isNull);
  });
}
