import 'dart:async';

import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

class AllLeaveRequestsViewModel extends ChangeNotifier {
  AllLeaveRequestsViewModel({
    this.initialStatus,
    this.initialFilter,
    LeaveRepository? repository,
  }) : _repository = repository ?? LeaveRepository();

  final String? initialStatus;
  final String? initialFilter;
  final LeaveRepository _repository;

  static const int _pageSize = LeaveRepository.defaultPageSize;

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _cursorRequestedAt;
  int? _cursorRequestId;
  String? _statusFilter;
  DateTimeRange? _dateRange;
  String _buttonLabel = '전체';
  final Set<int> _processingIds = {};
  final DateTime _today = DateTime.now();
  int _requestSeq = 0;
  bool _disposed = false;

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
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

  Future<List<LeaveRequestListItem>> _fetchPage({
    bool continueFromCursor = false,
  }) {
    final year = _today.year;
    var startDate = formatDate(DateTime(year, 1, 1));
    var endDate = formatDate(DateTime(year, 12, 31));
    if (_dateRange != null) {
      startDate = formatDate(_dateRange!.start);
      endDate = formatDate(_dateRange!.end);
    }

    return _buttonLabel == '내 신청'
        ? _repository.fetchMyLeaveRequestsPage(
            status: _statusFilter,
            startDate: startDate,
            endDate: endDate,
            page: 0,
            size: _pageSize,
            cursorRequestedAt:
                continueFromCursor ? _cursorRequestedAt : null,
            cursorRequestId: continueFromCursor ? _cursorRequestId : null,
          )
        : _repository.fetchAllLeaveRequestsPage(
            status: _statusFilter,
            startDate: startDate,
            endDate: endDate,
            page: 0,
            size: _pageSize,
            cursorRequestedAt:
                continueFromCursor ? _cursorRequestedAt : null,
            cursorRequestId: continueFromCursor ? _cursorRequestId : null,
          );
  }

  Future<void> fetch() async {
    final seq = ++_requestSeq;
    _isLoading = true;
    _isLoadingMore = false;
    _hasMore = true;
    _cursorRequestedAt = null;
    _cursorRequestId = null;
    _notify();

    try {
      final page = await _fetchPage();
      if (_disposed || seq != _requestSeq) return;
      _items = page;
      _applyPageCursor(page);
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore) return;

    final seq = _requestSeq;
     _isLoadingMore = true;
    _notify();
    try {
      final page = await _fetchPage(continueFromCursor: true);
      if (_disposed || seq != _requestSeq) return;

      final existingIds = _items.map((item) => item.requestId).toSet();
      _items.addAll(page.where((item) => existingIds.add(item.requestId)));
      _applyPageCursor(page);
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  void _applyPageCursor(List<LeaveRequestListItem> page) {
    _hasMore = page.length == _pageSize;
    if (page.isNotEmpty) {
      final last = page.last;
      _cursorRequestedAt = last.requestedAt;
      _cursorRequestId = last.requestId;
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
    LeaveRequestListItem item,
    String? userEmployeeNumber, {
    DateTime? now,
  }) {
    if (userEmployeeNumber == null ||
        item.employeeNumber != userEmployeeNumber) {
      return false;
    }
    if (item.status == 'PENDING') return true;
    if (item.status != 'APPROVED') return false;

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final start = DateTime.tryParse(item.startDate);
    if (start == null) return false;
    return DateTime(start.year, start.month, start.day).isAfter(today);
  }

  static String formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    super.dispose();
  }
}
