import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';

/// 로그인 사용자 정보를 고정 값으로 돌려주는 AuthSession 대역.
class FakeAuthSession extends AuthSession {
  FakeAuthSession({Employee? employeeInfo}) : _fakeEmployeeInfo = employeeInfo;

  final Employee? _fakeEmployeeInfo;

  int fetchMyInfoCount = 0;
  final List<String> updatedEmails = [];

  Object? loginErrorToThrow;
  final List<Map<String, String>> loginCalls = [];

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

  @override
  Future<void> login(String employeeNumber, String password) async {
    loginCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (loginErrorToThrow != null) throw loginErrorToThrow!;
  }

}
