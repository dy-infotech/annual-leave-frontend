import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:dio/dio.dart';

// 휴가 신청 조회와 변경 요청을 담당한다
class LeaveRepository {
  LeaveRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  static const int defaultPageSize = 50;
  static const int _maxCursorBatches = 1000;

  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    final response = await _dio.authenticatedGet('/api/leave-requests/$requestId');
    return LeaveRequestDetail.fromJson(response.data);
  }

  Future<LeavePeriod> fetchMyLeavePeriod() async {
    final response = await _dio.authenticatedGet('/api/leave-requests/my/period');
    return LeavePeriod.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<PageResult<LeaveRequestListItem>> fetchMyLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = defaultPageSize,
    String? cursorRequestedAt,
    int? cursorRequestId,
  }) async {
    final response = await _dio.authenticatedGet(
      '/api/leave-requests/my',
      queryParameters: _pageQuery(
        {
          if (status != null) 'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (cursorRequestedAt != null && cursorRequestId != null)
            'cursorRequestedAt': cursorRequestedAt,
          if (cursorRequestedAt != null && cursorRequestId != null)
            'cursorRequestId': cursorRequestId,
        },
        page: page,
        size: size,
      ),
    );
    return _parseLeavePage(response.data);
  }

  Future<PageResult<LeaveRequestListItem>> fetchAllLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = defaultPageSize,
    String? cursorRequestedAt,
    int? cursorRequestId,
  }) async {
    final response = await _dio.authenticatedGet(
      '/api/leave-requests/all',
      queryParameters: _pageQuery(
        {
          if (status != null) 'status': status,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (cursorRequestedAt != null && cursorRequestId != null)
            'cursorRequestedAt': cursorRequestedAt,
          if (cursorRequestedAt != null && cursorRequestId != null)
            'cursorRequestId': cursorRequestId,
        },
        page: page,
        size: size,
      ),
    );
    return _parseLeavePage(response.data);
  }

  // 캘린더와 중복 검사에 필요한 내 신청 목록을 끝까지 수집한다
  Future<List<LeaveRequestListItem>> fetchMyLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    return _collectLeaveCursorPages((cursorAt, cursorId) {
      return fetchMyLeaveRequestsPage(
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: 0,
        cursorRequestedAt: cursorAt,
        cursorRequestId: cursorId,
      );
    });
  }

  // 조직 전체 신청 목록을 끝까지 수집한다
  Future<List<LeaveRequestListItem>> fetchAllLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    return _collectLeaveCursorPages((cursorAt, cursorId) {
      return fetchAllLeaveRequestsPage(
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: 0,
        cursorRequestedAt: cursorAt,
        cursorRequestId: cursorId,
      );
    });
  }

  Future<void> cancelLeaveRequest(int requestId) async {
    await _dio.authenticatedDelete('/api/leave-requests/$requestId');
  }

  Future<void> submitLeaveRequest(
    LeaveRequestCreate request, {
    String? idempotencyKey,
  }) async {
    await _dio.authenticatedPost(
      '/api/leave-requests',
      data: request.toJson(),
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<PageResult<LeaveRequestListItem>> searchAdminLeaveRequestsPage({
    required String? status,
    required String? team,
    String? employeeParam,
    int page = 0,
    int size = defaultPageSize,
    String? cursorCreatedAt,
    int? cursorRequestId,
  }) async {
    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != 'approved' && normalizedStatus != 'rejected') {
      throw ArgumentError.value(
          status, 'status', 'approved 또는 rejected 상태가 필요합니다.');
    }

    final normalizedTeam = team?.trim();
    final normalizedEmployeeParam = employeeParam?.trim();
    final response = await _dio.authenticatedGet(
      '/api/admin/leave-requests/$normalizedStatus',
      queryParameters: _pageQuery(
        {
          if (normalizedTeam != null && normalizedTeam.isNotEmpty)
            'team': normalizedTeam,
          if (normalizedEmployeeParam != null &&
              normalizedEmployeeParam.isNotEmpty)
            'employeeParam': normalizedEmployeeParam,
          if (cursorCreatedAt != null && cursorRequestId != null)
            'cursorCreatedAt': cursorCreatedAt,
          if (cursorCreatedAt != null && cursorRequestId != null)
            'cursorRequestId': cursorRequestId,
        },
        page: page,
        size: size,
      ),
    );
    return _parseLeavePage(response.data);
  }

  Future<List<LeaveRequestListItem>> searchAdminLeaveRequests({
    required String? status,
    required String? team,
    String? employeeParam,
  }) {
    return _collectLeaveCursorPages((cursorAt, cursorId) {
      return searchAdminLeaveRequestsPage(
        status: status,
        team: team,
        employeeParam: employeeParam,
        page: 0,
        cursorCreatedAt: cursorAt,
        cursorRequestId: cursorId,
      );
    });
  }

  Future<PageResult<PendingLeaveRequest>> fetchPendingLeaveRequestsPage({
    int page = 0,
    int size = defaultPageSize,
    String? cursorCreatedAt,
    int? cursorRequestId,
  }) async {
    final response = await _dio.authenticatedGet(
      '/api/admin/leave-requests/pending',
      queryParameters: _pageQuery(
        {
          if (cursorCreatedAt != null && cursorRequestId != null)
            'cursorCreatedAt': cursorCreatedAt,
          if (cursorCreatedAt != null && cursorRequestId != null)
            'cursorRequestId': cursorRequestId,
        },
        page: page,
        size: size,
      ),
    );
    return _parsePendingPage(response.data);
  }

  // 결재 대기 목록을 다음 위치가 없을 때까지 수집한다
  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequests() async {
    final result = <PendingLeaveRequest>[];
    String? cursorCreatedAt;
    int? cursorRequestId;

    for (var batch = 0; batch < _maxCursorBatches; batch++) {
      final page = await fetchPendingLeaveRequestsPage(
        page: 0,
        cursorCreatedAt: cursorCreatedAt,
        cursorRequestId: cursorRequestId,
      );
      result.addAll(page.items);
      if (!page.hasMore) return result;
      if (page.items.isEmpty) return result;

      final last = page.items.last;
      final nextCursorCreatedAt = last.createdAt;
      final nextCursorRequestId = last.requestId;
      if (nextCursorCreatedAt == cursorCreatedAt &&
          nextCursorRequestId == cursorRequestId) {
        throw StateError('결재 대기 목록 cursor가 전진하지 않았습니다.');
      }
      cursorCreatedAt = nextCursorCreatedAt;
      cursorRequestId = nextCursorRequestId;
    }
    throw StateError('결재 대기 목록이 cursor 조회 한도를 초과했습니다.');
  }

  Future<void> approveLeaveRequest(int requestId) async {
    await _dio.authenticatedPost('/api/admin/leave-requests/$requestId/approve');
  }

  Future<void> rejectLeaveRequest(int requestId, {String? rejectReason}) async {
    await _dio.authenticatedPost(
      '/api/admin/leave-requests/$requestId/reject',
      data: {'rejectReason': rejectReason},
    );
  }

  PageResult<LeaveRequestListItem> _parseLeavePage(dynamic data) {
    final json = Map<String, dynamic>.from(data as Map);
    final items = (json['items'] as List? ?? const [])
        .map((item) => LeaveRequestListItem.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
    return PageResult(
      items: items,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }

  PageResult<PendingLeaveRequest> _parsePendingPage(dynamic data) {
    final json = Map<String, dynamic>.from(data as Map);
    final items = (json['items'] as List? ?? const [])
        .map((item) => PendingLeaveRequest.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
    return PageResult(
      items: items,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] == true,
    );
  }

  Map<String, dynamic> _pageQuery(
    Map<String, dynamic> base, {
    required int page,
    required int size,
  }) {
    return {
      ...base,
      'page': page,
      'size': size,
    };
  }

  // 목록의 마지막 위치를 이어가며 전체 결과를 수집한다
  Future<List<LeaveRequestListItem>> _collectLeaveCursorPages(
    Future<PageResult<LeaveRequestListItem>> Function(
      String? cursorCreatedAt,
      int? cursorRequestId,
    ) fetchPage,
  ) async {
    final result = <LeaveRequestListItem>[];
    String? cursorCreatedAt;
    int? cursorRequestId;

    for (var batch = 0; batch < _maxCursorBatches; batch++) {
      final page = await fetchPage(cursorCreatedAt, cursorRequestId);
      result.addAll(page.items);
      if (!page.hasMore) return result;
      if (page.items.isEmpty) return result;

      final last = page.items.last;
      final nextCursorCreatedAt = last.requestedAt;
      final nextCursorRequestId = last.requestId;
      if (nextCursorCreatedAt == cursorCreatedAt &&
          nextCursorRequestId == cursorRequestId) {
        throw StateError('휴가 목록 cursor가 전진하지 않았습니다.');
      }
      cursorCreatedAt = nextCursorCreatedAt;
      cursorRequestId = nextCursorRequestId;
    }
    throw StateError('휴가 목록이 cursor 조회 한도를 초과했습니다.');
  }
}
