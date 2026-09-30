import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:dio/dio.dart';

/// 휴가 신청 관련 API 호출 모음.
class LeaveRepository {
  LeaveRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  static const int defaultPageSize = 50;
  static const int _maxCursorBatches = 1000;

  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    final response = await _dio.get('/api/leave-requests/$requestId');
    return LeaveRequestDetail.fromJson(response.data);
  }

  Future<LeavePeriod> fetchMyLeavePeriod() async {
    final response = await _dio.get('/api/leave-requests/my/period');
    return LeavePeriod.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<List<LeaveRequestListItem>> fetchMyLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    String? cursorCreatedAt,
    int? cursorRequestId,
    int size = defaultPageSize,
  }) async {
    final response = await _dio.get(
      '/api/leave-requests/my',
      queryParameters: _cursorQuery(
        {
          if (status != null) 'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
        size: size,
      ),
    );
    return (response.data as List)
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
  }

  Future<List<LeaveRequestListItem>> fetchAllLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    String? cursorCreatedAt,
    int? cursorRequestId,
    int size = defaultPageSize,
  }) async {
    final response = await _dio.get(
      '/api/leave-requests/all',
      queryParameters: _cursorQuery(
        {
          if (status != null) 'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
        size: size,
      ),
    );
    return (response.data as List)
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
  }

  /// 캘린더/중복 검사처럼 전체 내역이 필요한 내부 호출용.
  Future<List<LeaveRequestListItem>> fetchMyLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    return _collectLeavePages((cursorCreatedAt, cursorRequestId) {
      return fetchMyLeaveRequestsPage(
        status: status,
        startDate: startDate,
        endDate: endDate,
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
      );
    });
  }

  /// 목록 UI는 fetchAllLeaveRequestsPage를 사용한다.
  Future<List<LeaveRequestListItem>> fetchAllLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    return _collectLeavePages((cursorCreatedAt, cursorRequestId) {
      return fetchAllLeaveRequestsPage(
        status: status,
        startDate: startDate,
        endDate: endDate,
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
      );
    });
  }

  Future<void> cancelLeaveRequest(int requestId) async {
    await _dio.delete('/api/leave-requests/$requestId');
  }

  Future<void> submitLeaveRequest(LeaveRequestCreate request) async {
    await _dio.post('/api/leave-requests', data: request.toJson());
  }

  Future<List<LeaveRequestListItem>> searchAdminLeaveRequestsPage({
    required String? status,
    required String? team,
    String? employeeParam,
    String? cursorCreatedAt,
    int? cursorRequestId,
    int size = defaultPageSize,
  }) async {
    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != 'approved' && normalizedStatus != 'rejected') {
      throw ArgumentError.value(
          status, 'status', 'approved 또는 rejected 상태가 필요합니다.');
    }

    final normalizedTeam = team?.trim();
    final normalizedEmployeeParam = employeeParam?.trim();
    final response = await _dio.get(
      '/api/admin/leave-requests/$normalizedStatus',
      queryParameters: _cursorQuery(
        {
          if (normalizedTeam != null && normalizedTeam.isNotEmpty)
            'team': normalizedTeam,
          if (normalizedEmployeeParam != null &&
              normalizedEmployeeParam.isNotEmpty)
            'employeeParam': normalizedEmployeeParam,
        },
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
        size: size,
      ),
    );
    return (response.data as List)
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
  }

  Future<List<LeaveRequestListItem>> searchAdminLeaveRequests({
    required String? status,
    required String? team,
    String? employeeParam,
  }) {
    return _collectLeavePages((cursorCreatedAt, cursorRequestId) {
      return searchAdminLeaveRequestsPage(
        status: status,
        team: team,
        employeeParam: employeeParam,
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
      );
    });
  }

  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequestsPage({
    String? cursorCreatedAt,
    int? cursorRequestId,
    int size = defaultPageSize,
  }) async {
    final response = await _dio.get(
      '/api/admin/leave-requests/pending',
      queryParameters: _cursorQuery(
        const {},
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
        size: size,
      ),
    );
    return (response.data as List)
        .map((json) => PendingLeaveRequest.fromJson(json))
        .toList();
  }

  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequests() async {
    final result = <PendingLeaveRequest>[];
    String? cursorCreatedAt;
    int? cursorRequestId;

    for (var batch = 0; batch < _maxCursorBatches; batch++) {
      final page = await fetchPendingLeaveRequestsPage(
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
      );
      result.addAll(page);
      if (page.length < defaultPageSize) return result;
      final last = page.last;
      cursorCreatedAt = last.createdAt;
      cursorRequestId = last.requestId;
    }
    throw StateError('결재 대기 목록이 cursor 조회 한도를 초과했습니다.');
  }

  Future<void> approveLeaveRequest(int requestId) async {
    await _dio.post('/api/admin/leave-requests/$requestId/approve');
  }

  Future<void> rejectLeaveRequest(int requestId, {String? rejectReason}) async {
    await _dio.post(
      '/api/admin/leave-requests/$requestId/reject',
      data: {'rejectReason': rejectReason},
    );
  }

  Map<String, dynamic> _cursorQuery(
    Map<String, dynamic> base, {
    required String? cursorCreatedAt,
    required int? cursorRequestId,
    required int size,
  }) {
    return {
      ...base,
      if (cursorCreatedAt != null) 'cursorCreatedAt': cursorCreatedAt,
      if (cursorRequestId != null) 'cursorRequestId': cursorRequestId,
      'size': size,
    };
  }

  Future<List<LeaveRequestListItem>> _collectLeavePages(
    Future<List<LeaveRequestListItem>> Function(
            String? cursorCreatedAt, int? cursorRequestId)
        fetchPage,
  ) async {
    final result = <LeaveRequestListItem>[];
    String? cursorCreatedAt;
    int? cursorRequestId;

    for (var batch = 0; batch < _maxCursorBatches; batch++) {
      final page = await fetchPage(cursorCreatedAt, cursorRequestId);
      result.addAll(page);
      if (page.length < defaultPageSize) return result;

      final last = page.last;
      cursorCreatedAt = last.requestedAt;
      cursorRequestId = last.requestId;
    }
    throw StateError('휴가 목록이 cursor 조회 한도를 초과했습니다.');
  }
}
