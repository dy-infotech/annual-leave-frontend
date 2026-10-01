import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';

/// LeaveRepository 인메모리 페이크.
///
/// 반환할 값을 필드에 미리 넣어두고, 호출 기록을 남긴다.
/// errorToThrow가 설정되면 해당 예외를 던진다.
class FakeLeaveRepository implements LeaveRepository {
  LeaveRequestDetail? detailToReturn;
  LeavePeriod leavePeriodToReturn = LeavePeriod(
    startDate: DateTime(DateTime.now().year, 1, 1),
    endDate: DateTime(DateTime.now().year, 12, 31),
  );
  List<LeaveRequestListItem> myLeaveRequestsToReturn = [];
  Object? errorToThrow;
  Object? cancelErrorToThrow;

  final List<int> fetchedDetailIds = [];
  int leavePeriodFetchCount = 0;
  final List<Map<String, String?>> myLeaveRequestQueries = [];
  final List<int> cancelledIds = [];

  @override
  Future<LeaveRequestDetail> fetchLeaveRequestDetail(int requestId) async {
    fetchedDetailIds.add(requestId);
    if (errorToThrow != null) throw errorToThrow!;
    return detailToReturn!;
  }

  @override
  Future<LeavePeriod> fetchMyLeavePeriod() async {
    leavePeriodFetchCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return leavePeriodToReturn;
  }

  @override
  Future<List<LeaveRequestListItem>> fetchMyLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = LeaveRepository.defaultPageSize,
    String? cursorRequestedAt,
    int? cursorRequestId,
  }) async {
    myLeaveRequestQueries
        .add({'status': status, 'startDate': startDate, 'endDate': endDate});
    if (errorToThrow != null) throw errorToThrow!;
    return myLeaveRequestsToReturn;
  }

  @override
  Future<List<LeaveRequestListItem>> fetchMyLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    myLeaveRequestQueries
        .add({'status': status, 'startDate': startDate, 'endDate': endDate});
    if (errorToThrow != null) throw errorToThrow!;
    return myLeaveRequestsToReturn;
  }

  @override
  Future<void> cancelLeaveRequest(int requestId) async {
    cancelledIds.add(requestId);
    if (cancelErrorToThrow != null) throw cancelErrorToThrow!;
  }

  List<LeaveRequestListItem> allLeaveRequestsToReturn = [];
  final List<Map<String, String?>> allLeaveRequestQueries = [];

  @override
  Future<List<LeaveRequestListItem>> fetchAllLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = LeaveRepository.defaultPageSize,
    String? cursorRequestedAt,
    int? cursorRequestId,
  }) async {
    allLeaveRequestQueries
        .add({'status': status, 'startDate': startDate, 'endDate': endDate});
    if (errorToThrow != null) throw errorToThrow!;
    return allLeaveRequestsToReturn;
  }

  @override
  Future<List<LeaveRequestListItem>> fetchAllLeaveRequests({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    allLeaveRequestQueries
        .add({'status': status, 'startDate': startDate, 'endDate': endDate});
    if (errorToThrow != null) throw errorToThrow!;
    return allLeaveRequestsToReturn;
  }

  Object? submitErrorToThrow;
  final List<LeaveRequestCreate> submittedRequests = [];
  final List<String?> submittedIdempotencyKeys = [];

  @override
  Future<void> submitLeaveRequest(
    LeaveRequestCreate request, {
    String? idempotencyKey,
  }) async {
    submittedRequests.add(request);
    submittedIdempotencyKeys.add(idempotencyKey);
    if (submitErrorToThrow != null) throw submitErrorToThrow!;
  }

  List<LeaveRequestListItem> adminSearchResultsToReturn = [];
  final Map<int, List<LeaveRequestListItem>> adminSearchResultsByPage = {};
  final List<Map<String, String?>> adminSearchQueries = [];
  final List<Map<String, int>> adminSearchPageRequests = [];

  @override
  Future<List<LeaveRequestListItem>> searchAdminLeaveRequestsPage({
    required String? status,
    required String? team,
    String? employeeParam,
    int page = 0,
    int size = LeaveRepository.defaultPageSize,
    String? cursorCreatedAt,
    int? cursorRequestId,
  }) async {
    adminSearchQueries
        .add({'status': status, 'team': team, 'employeeParam': employeeParam});
    adminSearchPageRequests.add({'page': page, 'size': size});
    if (errorToThrow != null) throw errorToThrow!;
    return adminSearchResultsByPage[page] ?? adminSearchResultsToReturn;
  }

  @override
  Future<List<LeaveRequestListItem>> searchAdminLeaveRequests({
    required String? status,
    required String? team,
    String? employeeParam,
  }) async {
    adminSearchQueries
        .add({'status': status, 'team': team, 'employeeParam': employeeParam});
    if (errorToThrow != null) throw errorToThrow!;
    return adminSearchResultsToReturn;
  }

  List<PendingLeaveRequest> pendingRequestsToReturn = [];
  Object? approveErrorToThrow;
  Object? rejectErrorToThrow;

  int pendingFetchCount = 0;
  final List<int> approvedIds = [];
  final List<Map<String, String?>> rejections = [];

  @override
  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequestsPage({
    int page = 0,
    int size = LeaveRepository.defaultPageSize,
    String? cursorCreatedAt,
    int? cursorRequestId,
  }) async {
    pendingFetchCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return pendingRequestsToReturn;
  }

  @override
  Future<List<PendingLeaveRequest>> fetchPendingLeaveRequests() async {
    pendingFetchCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return pendingRequestsToReturn;
  }

  @override
  Future<void> approveLeaveRequest(int requestId) async {
    approvedIds.add(requestId);
    if (approveErrorToThrow != null) throw approveErrorToThrow!;
  }

  @override
  Future<void> rejectLeaveRequest(int requestId, {String? rejectReason}) async {
    rejections.add({'requestId': '$requestId', 'rejectReason': rejectReason});
    if (rejectErrorToThrow != null) throw rejectErrorToThrow!;
  }
}
