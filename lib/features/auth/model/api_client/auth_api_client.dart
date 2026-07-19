import '../../../../core/network/api_client.dart';
import '../dto/auth_dto.dart';

// Model: 로그인 API 호출과 세션 토큰 저장/조회/삭제만 담당.
// "화면에 뭘 보여줄지"는 전혀 모르고, ApiClient(core 인프라)만 사용.
class AuthApiClient {
  final ApiClient _apiClient;
  AuthApiClient(this._apiClient);

  Future<LoginResponseDto> login(String employeeNumber, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequestDto(employeeNumber: employeeNumber, password: password).toJson(),
    );
    return LoginResponseDto.fromJson(response.data);
  }

  Future<void> saveSession(String token) => _apiClient.saveToken(token);

  Future<String?> getStoredToken() => _apiClient.getToken();

  Future<void> clearSession() => _apiClient.clearToken();
}
