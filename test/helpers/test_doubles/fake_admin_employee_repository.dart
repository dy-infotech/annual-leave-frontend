import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';

/// AdminEmployeeRepository 인메모리 페이크.
class FakeAdminEmployeeRepository implements AdminEmployeeRepository {
  List<Employee> employeesToReturn = [];
  Object? errorToThrow;

  final List<String?> fetchQueries = [];

  @override
  Future<List<Employee>> fetchEmployees({String? searchParam}) async {
    fetchQueries.add(searchParam);
    if (errorToThrow != null) throw errorToThrow!;
    return employeesToReturn;
  }
}
