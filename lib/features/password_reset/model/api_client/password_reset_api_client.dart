import '../../../../core/network/api_client.dart';

// Model: 비밀번호 재설정(이메일 발송) API 호출만 담당.
class PasswordResetApiClient {
  final ApiClient _apiClient;
  PasswordResetApiClient(this._apiClient);

  Future<void> sendResetEmail(String employeeNumber, String email) async {
    final response = await _apiClient.dio.post(
      '/api/auth/forgot-password',
      data: {'employeeNumber': employeeNumber, 'email': email},
    );

    if (response.statusCode != 200) {
      throw Exception('발송 실패');
    }
  }
}
