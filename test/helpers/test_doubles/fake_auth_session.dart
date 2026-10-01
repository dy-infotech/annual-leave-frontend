import 'dart:async';

import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';

/// 로그인 사용자 정보를 고정 값으로 돌려주는 AuthSession 대역.
class FakeAuthSession extends AuthSession {
  FakeAuthSession({
    Employee? employeeInfo,
    bool? isAdmin,
  })  : _fakeEmployeeInfo = employeeInfo,
        _fakeIsAdmin = isAdmin ?? employeeInfo?.role == 'ADMIN';

  final Employee? _fakeEmployeeInfo;
  final bool _fakeIsAdmin;

  int fetchMyInfoCount = 0;
  Completer<void>? fetchMyInfoCompleter;
  int logoutCount = 0;
  final List<String> updatedEmails = [];

  Object? loginErrorToThrow;
  final List<Map<String, String>> loginCalls = [];

  @override
  Employee? get employeeInfo => _fakeEmployeeInfo;

  @override
  bool get isAdmin => _fakeIsAdmin;

  @override
  Future<void> fetchMyInfo() async {
    fetchMyInfoCount++;
    await fetchMyInfoCompleter?.future;
  }

  @override
  Future<void> logout({String? fcmToken}) async {
    logoutCount++;
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    updatedEmails.add(newEmail);
  }

  @override
  Future<void> login(String employeeNumber, String password) async {
    loginCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (loginErrorToThrow != null) throw loginErrorToThrow!;
  }

}
