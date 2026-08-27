import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';

/// 로그인 사용자 정보를 고정 값으로 돌려주는 AuthProvider 대역.
class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({Employee? employeeInfo}) : _fakeEmployeeInfo = employeeInfo;

  final Employee? _fakeEmployeeInfo;

  int fetchMyInfoCount = 0;
  final List<String> updatedEmails = [];

  @override
  Employee? get employeeInfo => _fakeEmployeeInfo;

  @override
  Future<void> fetchMyInfo() async {
    fetchMyInfoCount++;
  }

  @override
  Future<void> updateEmail(newEmail) async {
    updatedEmails.add(newEmail as String);
  }
}
