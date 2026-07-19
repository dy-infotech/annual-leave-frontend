import '../../../../core/network/api_client.dart';
import '../dto/admin_registration_dto.dart';

// Model: 신규 사원 등록 관련 API 호출(옵션 목록 조회 + 등록)만 담당.
// 기존에는 이 두 API 호출이 signup_manage_screen(View) 안에 직접 있었음.
class AdminRegistrationApiClient {
  final ApiClient _apiClient;
  AdminRegistrationApiClient(this._apiClient);

  Future<RegistrationCommonOptionsDto> fetchCommonOptions() async {
    final response = await _apiClient.dio.get('/api/admin/auth/common');
    final data = response.data as Map<String, dynamic>;
    if (data.length < 3) {
      throw Exception('기초데이터 조회에 실패했습니다.');
    }
    return RegistrationCommonOptionsDto.fromJson(data);
  }

  Future<void> register(AdminAuthRegisterRequestDto request) async {
    await _apiClient.dio.post('/api/admin/auth/register', data: request.toJson());
  }
}
