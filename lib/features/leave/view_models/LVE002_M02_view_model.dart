import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

/// 전직원 휴가 신청 목록 화면(LVE002_M02)의 ViewModel.
class AllLeaveRequestsViewModel extends ChangeNotifier {
  AllLeaveRequestsViewModel({
    this.initialStatus,
    this.initialFilter,
    LeaveRepository? repository,
  }) : _repository = repository ?? LeaveRepository();

  final String? initialStatus;
  final String? initialFilter;
  final LeaveRepository _repository;

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;
  String _buttonLabel = '전체'; //로드 시 기본 버튼 라벨
  final Set<int> _processingIds = {};
  // 오늘 날짜 구하기
  final DateTime _today = DateTime.now();

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get statusFilter => _statusFilter;
  DateTimeRange? get dateRange => _dateRange;
  String get buttonLabel => _buttonLabel;
  bool isProcessing(int requestId) => _processingIds.contains(requestId);

  /// 화면 진입 시 1회 호출한다.
  Future<void> load() async {
    if (initialStatus != null) {
      _statusFilter = initialStatus;

      if (initialFilter != null) {
        _buttonLabel = initialFilter! == 'my' ? "내 신청" : "전체";
      }
      setFilter(initialStatus);
    }

    await fetch();
  }

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      // 기본 당해년도 조회 날짜 세팅
      int year = _today.year;
      DateTime firstDayOfYear = DateTime(year, 1, 1);
      DateTime lastDayOfYear = DateTime(year, 12, 31);

      String startDate = formatDate(firstDayOfYear);
      String endDate = formatDate(lastDayOfYear);

      if (_dateRange != null) {
        startDate = formatDate(_dateRange!.start);
        endDate = formatDate(_dateRange!.end);
      }

      final items = _buttonLabel == "내 신청"
          ? await _repository.fetchMyLeaveRequests(
              status: _statusFilter, startDate: startDate, endDate: endDate)
          : await _repository.fetchAllLeaveRequests(
              status: _statusFilter, startDate: startDate, endDate: endDate);
      _items = items;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
    fetch();
  }

  /// 조회 범위 라디오(전체/내 신청) 변경. 현재 상태 필터를 유지한 채 재조회한다.
  void setButtonLabel(String label) {
    _buttonLabel = label;
    setFilter(_statusFilter);
  }

  /// 기간이 실제로 바뀐 경우에만 반영하고 재조회한다.
  void setDateRange(DateTimeRange picked) {
    if (picked == _dateRange) return;
    _dateRange = picked;
    notifyListeners();
    fetch();
  }

  void clearDateRange() {
    _dateRange = null;
    notifyListeners();
    fetch();
  }

  /// 신청 취소. 성공 여부를 돌려주며, 성공 시 목록을 재조회한다.
  Future<bool> cancel(int requestId) async {
    _processingIds.add(requestId);
    notifyListeners();
    try {
      await _repository.cancelLeaveRequest(requestId);
      await fetch();
      return true;
    } catch (e) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      notifyListeners();
    }
  }

  static bool isCancelable(LeaveRequestListItem item, userEmployeeNumber) {
    if (item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber) {
      return true;
    }

    return false;

    /*if (item.status != 'PENDING' && item.status != 'APPROVED') return false;

    final startDate = DateTime.parse(item.startDate);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // 휴가 시작일이 오늘이거나 이미 지났으면 취소 불가
    return startDate.isAfter(todayDateOnly); */
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'; //yyyy-mm-dd
}
