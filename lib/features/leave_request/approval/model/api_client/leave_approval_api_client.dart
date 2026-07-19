import '../../../../../core/network/api_client.dart';
import '../dto/pending_leave_request_dto.dart';

// 승인 대기 목록 조회/승인/반려. approval feature 전용 서비스.
class LeaveApprovalApiClient {
  final ApiClient _apiClient;
  LeaveApprovalApiClient(this._apiClient);

  Future<List<PendingLeaveRequestDto>> fetchPending() async {
    final response = await _apiClient.dio.get('/api/admin/leave-requests/pending');
    return (response.data as List).map((json) => PendingLeaveRequestDto.fromJson(json)).toList();
  }

  Future<void> approve(int requestId) async {
    await _apiClient.dio.post('/api/admin/leave-requests/$requestId/approve');
  }

  Future<void> reject(int requestId, String reason) async {
    await _apiClient.dio.post(
      '/api/admin/leave-requests/$requestId/reject',
      data: {'rejectReason': reason.isEmpty ? null : reason},
    );
  }
}
