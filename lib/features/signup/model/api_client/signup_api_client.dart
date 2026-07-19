import '../../../../core/network/api_client.dart';
import '../dto/signup_dto.dart';

// Model: 본인 회원가입(사용 등록) API 호출만 담당.
// 로그인 세션과는 무관한 별개의 일회성 동작이라 auth와 분리된 feature로 뺌.
class SignupApiClient {
  final ApiClient _apiClient;
  SignupApiClient(this._apiClient);

  Future<void> signUp(String employeeNumber, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequestDto(employeeNumber: employeeNumber, password: password).toJson(),
    );
  }
}
