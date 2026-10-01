import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';

// 로그인과 계정 관련 서버 요청을 담당한다
class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  // 로그인 응답을 받은 뒤 세션 저장은 호출부에서 처리한다
  Future<LoginResponse> signIn(String employeeNumber, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(
        employeeNumber: employeeNumber,
        password: password,
      ).toJson(),
    );
    return LoginResponse.fromJson(response.data);
  }

  // 로그인과 로컬 세션 저장을 같은 세션 잠금에서 처리한다
  Future<T> runSharedSsoMutation<T>(Future<T> Function() action) =>
      _apiClient.runSharedSsoMutation(action);

  // 현재 로그인 사용자의 정보를 조회한다
  Future<Employee> fetchMyInfo() async {
    final response = await _apiClient.authenticatedRequest(
      '/api/employees/me',
      method: 'GET',
    );
    return Employee.fromJson(response.data);
  }

  // 사용자 등록을 요청한다
  Future<void> signUp(String employeeNumber, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
  }

  // 비밀번호 재설정 메일을 요청한다
  Future<void> sendPasswordResetEmail(
      String employeeNumber, String email) async {
    final response = await _apiClient.dio.post(
      '/api/auth/forgot-password',
      data: {'employeeNumber': employeeNumber, 'email': email},
    );

    if (response.statusCode != 200) {
      throw Exception('발송 실패');
    }
  }

  // 재설정 토큰으로 새 비밀번호를 저장한다
  Future<void> resetPassword(String token, String newPassword) async {
    final response = await _apiClient.dio.post(
      '/api/auth/reset-password',
      data: {
        'token': token,
        'newPassword': newPassword,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('비밀번호 재설정 실패');
    }
  }

  // 사번 안내 메일을 요청한다
  Future<void> findId(String name, String email) async {
    final response = await _apiClient.dio.post(
      '/api/auth/find-id',
      data: {
        'name': name,
        'email': email,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('발송 실패');
    }
  }

  // 로그인 응답의 액세스 토큰을 저장한다
  Future<void> saveToken(
    String token, {
    String? ssoSessionMarker,
  }) =>
      _apiClient.saveToken(
        token,
        sessionMarker: ssoSessionMarker,
      );

  // 저장된 세션을 복원하고 필요하면 토큰을 갱신한다
  Future<String?> getToken() async {
    final session = await _apiClient.restoreSession();
    return session?.token;
  }

  // 로그인 확정 실패 시 생성된 서버 세션을 정리한다
  Future<void> discardRefreshSession(
    String sessionMarker, {
    bool clearLocalState = true,
  }) =>
      _apiClient.discardRefreshSession(
        sessionMarker,
        clearLocalState: clearLocalState,
      );

  // 서버 로그아웃을 요청하고 로컬 세션을 정리한다
  Future<void> logout({String? fcmToken}) =>
      _apiClient.logoutSession(fcmToken: fcmToken);

  // 서버 호출 없이 로컬 토큰만 정리한다
  Future<void> clearToken() => _apiClient.clearToken();
}
