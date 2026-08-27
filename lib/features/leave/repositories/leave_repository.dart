import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:dio/dio.dart';

/// 휴가 신청 관련 API 호출 모음.
///
/// 오류는 기존 화면들과 동일하게 예외를 그대로 던진다.
/// (Result/Failure 반환으로의 전환은 마이그레이션 8단계에서 일괄 적용)
class LeaveRepository {
  final Dio _dio;

  LeaveRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// 휴가 신청 상세 조회. GET /api/leave-requests/{requestId}
  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    final response = await _dio.get('/api/leave-requests/$requestId');
    return LeaveRequestDetail.fromJson(response.data);
  }

  /// 내 휴가 신청 목록 조회. GET /api/leave-requests/my
  ///
  /// 조건이 하나도 없으면 쿼리 파라미터 없이 호출한다. (기존 화면과 동일)
  Future<List<LeaveRequestListItem>> fetchMyLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null) 'status': status,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final response = await _dio.get(
      '/api/leave-requests/my',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return (response.data as List)
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
  }

  /// 전직원 휴가 신청 목록 조회. GET /api/leave-requests/all
  Future<List<LeaveRequestListItem>> fetchAllLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null) 'status': status,
      if (startDate != null) 'startDate': startDate,
      if (endDate != null) 'endDate': endDate,
    };
    final response = await _dio.get(
      '/api/leave-requests/all',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return (response.data as List)
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
  }

  /// 휴가 신청 취소. DELETE /api/leave-requests/{requestId}
  Future<void> cancelLeaveRequest(int requestId) async {
    await _dio.delete('/api/leave-requests/$requestId');
  }

  /// 결재 대기 목록 조회. GET /api/admin/leave-requests/pending
  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequests() async {
    final response = await _dio.get('/api/admin/leave-requests/pending');
    return (response.data as List)
        .map((json) => PendingLeaveRequest.fromJson(json))
        .toList();
  }

  /// 휴가 신청 승인. POST /api/admin/leave-requests/{requestId}/approve
  Future<void> approveLeaveRequest(int requestId) async {
    await _dio.post('/api/admin/leave-requests/$requestId/approve');
  }

  /// 휴가 신청 반려. POST /api/admin/leave-requests/{requestId}/reject
  ///
  /// 사유 미입력 시 rejectReason은 null로 전송한다. (기존 화면과 동일)
  Future<void> rejectLeaveRequest(int requestId, {String? rejectReason}) async {
    await _dio.post(
      '/api/admin/leave-requests/$requestId/reject',
      data: {'rejectReason': rejectReason},
    );
  }
}
