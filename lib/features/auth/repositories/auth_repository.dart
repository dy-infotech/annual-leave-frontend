import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';

/// 계정 관련 API 호출 모음. (로그인, 내 정보, 등록, 비밀번호 찾기/재설정, 로그아웃)
///
/// 토큰 저장/삭제는 [ApiClient]에 위임한다. 오류는 가공하지 않고 DioException을 그대로 던진다.
class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 로그인. POST /api/auth/signin.
  ///
  /// 응답 토큰 저장은 AuthSession이 세대 검증을 마친 뒤 수행한다.
  Future<LoginResponse> signIn(String employeeNumber, String password) async {
    final response = await _apiClient.runSharedSsoMutation(() {
      return _apiClient.dio.post(
        '/api/auth/signin',
        data: LoginRequest(
          employeeNumber: employeeNumber,
          password: password,
        ).toJson(),
      );
    });
    return LoginResponse.fromJson(response.data);
  }

  /// 내 정보 조회. GET /api/employees/me
  Future<Employee> fetchMyInfo() async {
    final response = await _apiClient.dio.get('/api/employees/me');
    return Employee.fromJson(response.data);
  }

  /// 사용 등록. POST /api/auth/signup
  Future<void> signUp(String employeeNumber, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
  }

  /// 비밀번호 재설정 메일 발송. POST /api/auth/forgot-password
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

  /// 이메일로 받은 일회용 token을 소비해 새 비밀번호를 설정한다.
  /// POST /api/auth/reset-password
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

  /// 아이디 찾기 메일 발송. POST /api/auth/find-id
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

  /// 로그인 응답으로 받은 액세스 토큰을 보안 저장소에 저장한다.
  Future<void> saveToken(
    String token, {
    String? ssoSessionMarker,
  }) =>
      _apiClient.saveToken(
        token,
        sessionMarker: ssoSessionMarker,
      );

  /// 자동 로그인용 액세스 토큰을 돌려준다. 저장된 토큰이 만료 임박이면 refresh로 갱신한 토큰을,
  /// 복원할 세션이 없으면 null을 돌려준다. (단순 조회가 아니라 갱신 요청이 포함될 수 있다)
  Future<String?> getToken() async {
    final session = await _apiClient.restoreSession();
    return session?.token;
  }

  /// signin 성공 뒤 로컬 세션 확정이 실패했을 때 해당 refresh session을 폐기한다.
  /// 같은 cookie session이 재시작 뒤 자동 복구되지 않도록 marker 기반 fence도 남긴다.
  Future<void> discardRefreshSession(
    String sessionMarker, {
    bool clearLocalState = true,
  }) =>
      _apiClient.discardRefreshSession(
        sessionMarker,
        clearLocalState: clearLocalState,
      );

  /// 로그아웃. 서버에 refresh 토큰 폐기를 요청하고 로컬 토큰을 지운다. 서버 요청이 실패해도 로컬은 로그아웃된다.
  Future<void> logout({String? fcmToken}) =>
      _apiClient.logoutSession(fcmToken: fcmToken);

  /// 서버 호출 없이 로컬에 저장된 토큰만 지운다.
  Future<void> clearToken() => _apiClient.clearToken();
}
