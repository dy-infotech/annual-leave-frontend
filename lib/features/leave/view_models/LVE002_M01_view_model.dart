import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

/// 내 휴가 신청 목록 화면(LVE002_M01)의 ViewModel.
class MyLeaveRequestsViewModel extends ChangeNotifier {
  MyLeaveRequestsViewModel({this.initialStatus, LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final String? initialStatus;
  final LeaveRepository _repository;

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;
  final Set<int> _processingIds = {};

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get statusFilter => _statusFilter;
  DateTimeRange? get dateRange => _dateRange;
  bool isProcessing(int requestId) => _processingIds.contains(requestId);

  /// 화면 진입 시 1회 호출한다.
  Future<void> load() async {
    if (initialStatus != null) {
      _statusFilter = initialStatus;
      setFilter(initialStatus);
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final items = await _repository.fetchMyLeaveRequests(
        status: _statusFilter,
        startDate: _dateRange != null ? formatDate(_dateRange!.start) : null,
        endDate: _dateRange != null ? formatDate(_dateRange!.end) : null,
      );
      _items = items;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
    _fetch();
  }

  void setDateRange(DateTimeRange range) {
    _dateRange = range;
    notifyListeners();
    _fetch();
  }

  void clearDateRange() {
    _dateRange = null;
    notifyListeners();
    _fetch();
  }

  /// 신청 취소. 성공 여부를 돌려주며, 성공 시 목록을 재조회한다.
  Future<bool> cancel(int requestId) async {
    _processingIds.add(requestId);
    notifyListeners();
    try {
      await _repository.cancelLeaveRequest(requestId);
      await _fetch();
      return true;
    } catch (e) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      notifyListeners();
    }
  }

  static bool isCancelable(LeaveRequestListItem item) {
    if (item.status == 'PENDING') return true;

    return false;

    /*if (item.status != 'PENDING' && item.status != 'APPROVED') return false;

    final startDate = DateTime.parse(item.startDate);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // 휴가 시작일이 오늘이거나 이미 지났으면 취소 불가
    return startDate.isAfter(todayDateOnly); */
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
