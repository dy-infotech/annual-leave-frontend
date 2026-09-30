import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';

/// AuthRepository 인메모리 페이크.
class FakeAuthRepository implements AuthRepository {
  Object? signInErrorToThrow;
  final List<Map<String, String>> signInCalls = [];
  LoginResponse signInResponse = LoginResponse(
      token: 'test.token', employeeId: 1, name: '홍길동', role: 'EMPLOYEE');

  Employee? myInfoToReturn;
  String? storedToken;

  Object? signUpErrorToThrow;
  final List<Map<String, String>> signUpCalls = [];

  Object? resetErrorToThrow;
  final List<Map<String, String>> resetCalls = [];

  Object? findIdErrorToThrow;
  final List<Map<String, String>> findIdCalls = [];

  @override
  Future<LoginResponse> signIn(String employeeNumber, String password) async {
    signInCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (signInErrorToThrow != null) throw signInErrorToThrow!;
    storedToken = signInResponse.token;
    return signInResponse;
  }

  @override
  Future<Employee> fetchMyInfo() async {
    if (myInfoToReturn == null) throw Exception('내 정보 없음');
    return myInfoToReturn!;
  }

  @override
  Future<void> signUp(String employeeNumber, String password) async {
    signUpCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (signUpErrorToThrow != null) throw signUpErrorToThrow!;
  }

  @override
  Future<void> sendPasswordResetEmail(
      String employeeNumber, String email) async {
    resetCalls.add({'employeeNumber': employeeNumber, 'email': email});
    if (resetErrorToThrow != null) throw resetErrorToThrow!;
  }

  @override
  Future<void> findId(String name, String email) async {
    findIdCalls.add({'name': name, 'email': email});
    if (findIdErrorToThrow != null) throw findIdErrorToThrow!;
  }

  @override
  Future<String?> getToken() async => storedToken;

  @override
  Future<void> clearToken() async {
    storedToken = null;
  }
}
