import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';

/// 계정 관련 API 호출 모음. (기존 전역 인증 provider에서 분리)
///
/// JWT 저장/삭제는 로그인 흐름과 붙어 있는 데이터 계층 관심사이므로 여기서 다룬다.
class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 로그인. POST /api/auth/signin. 성공 시 JWT를 저장하고 응답을 돌려준다.
  Future<LoginResponse> signIn(String employeeNumber, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
    final loginResponse = LoginResponse.fromJson(response.data);
    await _apiClient.saveToken(loginResponse.token);
    return loginResponse;
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

  Future<String?> getToken() => _apiClient.getToken();

  Future<void> clearToken() => _apiClient.clearToken();
}
