import 'dart:async';

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
  String? _statusFilter;
  DateTimeRange? _dateRange;
  String _buttonLabel = '전체';
  final Set<int> _processingIds = {};
  final DateTime _today = DateTime.now();
  int _requestSeq = 0;
  bool _disposed = false;

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get statusFilter => _statusFilter;
  DateTimeRange? get dateRange => _dateRange;
  String get buttonLabel => _buttonLabel;
  bool isProcessing(int requestId) => _processingIds.contains(requestId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _statusFilter = initialStatus;
    if (initialFilter != null) {
      _buttonLabel = initialFilter == 'my' ? '내 신청' : '전체';
    }
    await fetch();
  }

  Future<void> fetch() async {
    final seq = ++_requestSeq;
    _isLoading = true;
    _notify();
    try {
      final year = _today.year;
      var startDate = formatDate(DateTime(year, 1, 1));
      var endDate = formatDate(DateTime(year, 12, 31));

      if (_dateRange != null) {
        startDate = formatDate(_dateRange!.start);
        endDate = formatDate(_dateRange!.end);
      }

      final items = _buttonLabel == '내 신청'
          ? await _repository.fetchMyLeaveRequests(
              status: _statusFilter, startDate: startDate, endDate: endDate)
          : await _repository.fetchAllLeaveRequests(
              status: _statusFilter, startDate: startDate, endDate: endDate);
      if (_disposed || seq != _requestSeq) return;
      _items = items;
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void setFilter(String? status) {
    _statusFilter = status;
    _notify();
    unawaited(fetch());
  }

  void setButtonLabel(String label) {
    _buttonLabel = label;
    _notify();
    unawaited(fetch());
  }

  void setDateRange(DateTimeRange picked) {
    if (picked == _dateRange) return;
    _dateRange = picked;
    _notify();
    unawaited(fetch());
  }

  void clearDateRange() {
    _dateRange = null;
    _notify();
    unawaited(fetch());
  }

  Future<bool> cancel(int requestId) async {
    _processingIds.add(requestId);
    _notify();
    try {
      await _repository.cancelLeaveRequest(requestId);
      await fetch();
      return true;
    } catch (_) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  static bool isCancelable(
          LeaveRequestListItem item, String? userEmployeeNumber) =>
      item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber;

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
