import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';

/// AuthRepository 인메모리 페이크.
class FakeAuthRepository implements AuthRepository {
  Object? signInErrorToThrow;
  Future<LoginResponse> Function(String employeeNumber, String password)?
      signInHandler;
  final List<Map<String, String>> signInCalls = [];
  LoginResponse signInResponse = LoginResponse(
      token: 'test.token', employeeId: 1, name: '홍길동', role: 'EMPLOYEE');

  Employee? myInfoToReturn;
  String? storedToken;
  String? storedSessionMarker;
  Object? saveTokenErrorToThrow;
  Object? getTokenErrorToThrow;
  Object? discardRefreshSessionErrorToThrow;
  final List<String> discardedSessionMarkers = [];
  final List<bool> discardClearLocalStates = [];

  Object? signUpErrorToThrow;
  final List<Map<String, String>> signUpCalls = [];

  Object? resetErrorToThrow;
  final List<Map<String, String>> resetCalls = [];
  Object? confirmResetErrorToThrow;
  final List<Map<String, String>> confirmResetCalls = [];

  Object? findIdErrorToThrow;
  final List<Map<String, String>> findIdCalls = [];

  Object? logoutErrorToThrow;
  int logoutCalls = 0;

  @override
  Future<T> runSharedSsoMutation<T>(Future<T> Function() action) => action();

  @override
  Future<LoginResponse> signIn(String employeeNumber, String password) async {
    signInCalls.add({'employeeNumber': employeeNumber, 'password': password});
    if (signInErrorToThrow != null) throw signInErrorToThrow!;
    final handler = signInHandler;
    if (handler != null) return handler(employeeNumber, password);
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
  Future<void> resetPassword(String token, String newPassword) async {
    confirmResetCalls.add({'token': token, 'newPassword': newPassword});
    if (confirmResetErrorToThrow != null) throw confirmResetErrorToThrow!;
  }

  @override
  Future<void> findId(String name, String email) async {
    findIdCalls.add({'name': name, 'email': email});
    if (findIdErrorToThrow != null) throw findIdErrorToThrow!;
  }

  @override
  Future<void> saveToken(
    String token, {
    String? ssoSessionMarker,
  }) async {
    if (saveTokenErrorToThrow != null) throw saveTokenErrorToThrow!;
    storedToken = token;
    storedSessionMarker = ssoSessionMarker;
  }

  @override
  Future<void> discardRefreshSession(
    String sessionMarker, {
    bool clearLocalState = true,
  }) async {
    discardedSessionMarkers.add(sessionMarker);
    discardClearLocalStates.add(clearLocalState);
    if (discardRefreshSessionErrorToThrow != null) {
      throw discardRefreshSessionErrorToThrow!;
    }
  }

  @override
  Future<void> logout({String? fcmToken}) async {
    logoutCalls++;
    if (logoutErrorToThrow != null) throw logoutErrorToThrow!;
    storedToken = null;
    storedSessionMarker = null;
  }

  @override
  Future<String?> getToken() async {
    if (getTokenErrorToThrow != null) throw getTokenErrorToThrow!;
    return storedToken;
  }

  @override
  Future<void> clearToken() async {
    storedToken = null;
    storedSessionMarker = null;
  }
}
