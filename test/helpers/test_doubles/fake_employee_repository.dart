import 'package:annual_leave_frontend/features/employee/repositories/employee_repository.dart';

/// EmployeeRepository 인메모리 페이크.
class FakeEmployeeRepository implements EmployeeRepository {
  Object? changePasswordErrorToThrow;
  Object? changeEmailErrorToThrow;

  final List<Map<String, String>> passwordChanges = [];
  final List<String> emailChanges = [];

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordChanges
        .add({'currentPassword': currentPassword, 'newPassword': newPassword});
    if (changePasswordErrorToThrow != null) throw changePasswordErrorToThrow!;
  }

  @override
  Future<void> changeEmail(String email) async {
    emailChanges.add(email);
    if (changeEmailErrorToThrow != null) throw changeEmailErrorToThrow!;
  }
}
