import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';

/// 로그인 사용자 정보를 고정 값으로 돌려주는 AuthProvider 대역.
class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider({Employee? employeeInfo}) : _fakeEmployeeInfo = employeeInfo;

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

  Object? signUpErrorToThrow;
  final List<Map<String, String>> signUpCalls = [];

  @override
  Future<void> signUp(String employeeNumber, String password) async {
    signUpCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (signUpErrorToThrow != null) throw signUpErrorToThrow!;
  }

  Object? resetErrorToThrow;
  final List<Map<String, String>> resetCalls = [];

  @override
  Future<void> sendPasswordResetEmail(
      String employeeNumber, String email) async {
    resetCalls.add({'employeeNumber': employeeNumber, 'email': email});
    if (resetErrorToThrow != null) throw resetErrorToThrow!;
  }

  Object? findIdErrorToThrow;
  final List<Map<String, String>> findIdCalls = [];

  @override
  Future<void> findId(String name, String email) async {
    findIdCalls.add({'name': name, 'email': email});
    if (findIdErrorToThrow != null) throw findIdErrorToThrow!;
  }
}
