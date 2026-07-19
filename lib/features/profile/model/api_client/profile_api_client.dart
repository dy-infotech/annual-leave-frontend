import '../../../../core/network/api_client.dart';
import '../dto/employee_dto.dart';

// Model: 내 정보 조회/이메일 변경/비밀번호 변경 API 호출만 담당.
// 기존에는 이 API 호출들이 my_info_screen(View) 안에 직접 박혀 있었음.
class ProfileApiClient {
  final ApiClient _apiClient;
  ProfileApiClient(this._apiClient);

  Future<EmployeeDto> fetchMyInfo() async {
    final response = await _apiClient.dio.get('/api/employees/me');
    return EmployeeDto.fromJson(response.data);
  }

  Future<void> changeEmail(String newEmail) async {
    await _apiClient.dio.patch(
      '/api/employees/me/modify-email',
      data: newEmail,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.dio.patch(
      '/api/employees/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
