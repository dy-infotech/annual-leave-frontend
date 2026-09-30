import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:dio/dio.dart';

/// 휴가 신청 관련 API 호출 모음.
///
/// 오류는 기존 화면들과 동일하게 예외를 그대로 던진다.
/// (Result/Failure 반환으로의 전환은 마이그레이션 8단계에서 일괄 적용)
class LeaveRepository {
  final Dio _dio;

  static const int _pageSize = 100;
  static const int _maxPages = 1000;

  LeaveRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  Future<List<T>> _fetchAllPages<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic json) fromJson,
  }) async {
    final result = <T>[];

    for (var page = 0; page < _maxPages; page++) {
      final params = <String, dynamic>{
        ...?queryParameters,
        if (page > 0) 'page': page,
        if (page > 0) 'size': _pageSize,
      };
      final response = await _dio.get(
        path,
        queryParameters: params.isEmpty ? null : params,
      );
      final raw = response.data as List;
      result.addAll(raw.map(fromJson));

      if (raw.length < _pageSize) {
        return result;
      }
    }

    throw StateError('휴가 목록이 서버 페이지 한도를 초과했습니다.');
  }

  /// 휴가 신청 상세 조회. GET /api/leave-requests/{requestId}
  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    final response = await _dio.get('/api/leave-requests/$requestId');
    return LeaveRequestDetail.fromJson(response.data);
  }

  /// 현재 적용 중인 내 연차기간 조회. GET /api/leave-requests/my/period
  ///
  /// 서버 정책이 회계연도/입사일 기준 중 무엇인지 프론트가 하드코딩하지 않고
  /// startDate/endDate 자체를 선택 가능 기간의 정본으로 사용한다.
  Future<LeavePeriod> fetchMyLeavePeriod() async {
    final response = await _dio.get('/api/leave-requests/my/period');
    return LeavePeriod.fromJson(Map<String, dynamic>.from(response.data));
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
    return _fetchAllPages(
      '/api/leave-requests/my',
      queryParameters: queryParams,
      fromJson: (json) => LeaveRequestListItem.fromJson(json),
    );
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
    return _fetchAllPages(
      '/api/leave-requests/all',
      queryParameters: queryParams,
      fromJson: (json) => LeaveRequestListItem.fromJson(json),
    );
  }

  /// 휴가 신청 취소. DELETE /api/leave-requests/{requestId}
  Future<void> cancelLeaveRequest(int requestId) async {
    await _dio.delete('/api/leave-requests/$requestId');
  }

  /// 휴가 신청 제출. POST /api/leave-requests
  Future<void> submitLeaveRequest(LeaveRequestCreate request) async {
    await _dio.post('/api/leave-requests', data: request.toJson());
  }

  /// 관리자 휴가 검색. GET /api/admin/leave-requests/{status}
  ///
  /// 기존 화면과 동일하게 status는 경로와 쿼리에 모두 실리고,
  /// team은 전체 선택 시 null 값으로 키가 유지된다. (dio가 null 값은 전송하지 않음)
  Future<List<LeaveRequestListItem>> searchAdminLeaveRequests({
    required String? status,
    required String? team,
    String? employeeParam,
  }) async {
    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != 'approved' && normalizedStatus != 'rejected') {
      throw ArgumentError.value(
          status, 'status', 'approved 또는 rejected 상태가 필요합니다.');
    }

    final normalizedTeam = team?.trim();
    final normalizedEmployeeParam = employeeParam?.trim();
    final queryParams = <String, dynamic>{
      if (normalizedTeam != null && normalizedTeam.isNotEmpty)
        'team': normalizedTeam,
      if (normalizedEmployeeParam != null && normalizedEmployeeParam.isNotEmpty)
        'employeeParam': normalizedEmployeeParam,
    };
    return _fetchAllPages(
      '/api/admin/leave-requests/$normalizedStatus',
      queryParameters: queryParams,
      fromJson: (json) => LeaveRequestListItem.fromJson(json),
    );
  }

  /// 결재 대기 목록 조회. GET /api/admin/leave-requests/pending
  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequests() {
    return _fetchAllPages(
      '/api/admin/leave-requests/pending',
      fromJson: (json) => PendingLeaveRequest.fromJson(json),
    );
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
