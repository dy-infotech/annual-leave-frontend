import '../../../../../core/network/api_client.dart';
import '../dto/leave_request_create_dto.dart';

// "휴가 신청 제출" API 하나만 담당. create feature 전용 서비스.
class LeaveRequestCreateApiClient {
  final ApiClient _apiClient;
  LeaveRequestCreateApiClient(this._apiClient);

  Future<void> create(LeaveRequestCreateDto request) async {
    await _apiClient.dio.post('/api/leave-requests', data: request.toJson());
  }
}
