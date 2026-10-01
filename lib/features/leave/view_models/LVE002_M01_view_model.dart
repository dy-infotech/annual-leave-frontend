import 'dart:async';

import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/material.dart';

enum CancelResult {
  failed,
  succeeded,
  succeededRefreshFailed,
}

// 내 휴가 신청 목록과 취소 상태를 관리한다
class MyLeaveRequestsViewModel extends ChangeNotifier {
  MyLeaveRequestsViewModel({this.initialStatus, LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final String? initialStatus;
  final LeaveRepository _repository;

  static const int _pageSize = LeaveRepository.defaultPageSize;

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  String? _loadError;
  String? _cursorRequestedAt;
  int? _cursorRequestId;
  String? _statusFilter;
  DateTimeRange? _dateRange;
  final Set<int> _processingIds = {};
  int _requestSeq = 0;
  bool _disposed = false;

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  String? get loadError => _loadError;
  String? get statusFilter => _statusFilter;
  DateTimeRange? get dateRange => _dateRange;
  bool isProcessing(int requestId) => _processingIds.contains(requestId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // 초기 상태 필터를 적용한 뒤 목록을 조회한다
  Future<void> load() async {
    _statusFilter = initialStatus;
    await _fetch();
  }

  Future<PageResult<LeaveRequestListItem>> _fetchPage({
    bool continueFromCursor = false,
  }) {
    return _repository.fetchMyLeaveRequestsPage(
      status: _statusFilter,
      startDate: _dateRange != null ? formatDate(_dateRange!.start) : null,
      endDate: _dateRange != null ? formatDate(_dateRange!.end) : null,
      page: 0,
      size: _pageSize,
      cursorRequestedAt:
          continueFromCursor ? _cursorRequestedAt : null,
      cursorRequestId: continueFromCursor ? _cursorRequestId : null,
    );
  }

  // 현재 조건으로 신청 목록을 처음부터 다시 조회한다
  Future<void> _fetch() async {
    final seq = ++_requestSeq;
    _isLoading = true;
    _isLoadingMore = false;
    _items = [];
    _hasMore = false;
    _totalCount = 0;
    _cursorRequestedAt = null;
    _cursorRequestId = null;
    _loadError = null;
    _notify();

    try {
      final page = await _fetchPage();
      if (_disposed || seq != _requestSeq) return;
      _items = List.of(page.items);
      _totalCount = page.totalCount;
      _loadError = null;
      _applyPageCursor(page.items, page.hasMore);
    } catch (_) {
      if (!_disposed && seq == _requestSeq) {
        _loadError = '목록을 불러오지 못했습니다.';
        _hasMore = false;
      }
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  // 현재 조건을 유지한 채 다음 신청 목록을 조회한다
  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore || _loadError != null) return;

    final seq = _requestSeq;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _fetchPage(continueFromCursor: true);
      if (_disposed || seq != _requestSeq) return;

      final existingIds = _items.map((item) => item.requestId).toSet();
      _items.addAll(
          page.items.where((item) => existingIds.add(item.requestId)));
      _totalCount = page.totalCount;
      _loadError = null;
      _applyPageCursor(page.items, page.hasMore);
    } catch (_) {
      if (!_disposed && seq == _requestSeq) {
        _loadError = '추가 목록을 불러오지 못했습니다.';
        _hasMore = false;
      }
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  void _applyPageCursor(
      List<LeaveRequestListItem> page, bool hasMore) {
    _hasMore = hasMore;
    if (page.isNotEmpty) {
      final last = page.last;
      _cursorRequestedAt = last.requestedAt;
      _cursorRequestId = last.requestId;
    }
  }

  void setFilter(String? status) {
    _statusFilter = status;
    _notify();
    unawaited(_fetch());
  }

  void setDateRange(DateTimeRange range) {
    _dateRange = range;
    _notify();
    unawaited(_fetch());
  }

  void clearDateRange() {
    _dateRange = null;
    _notify();
    unawaited(_fetch());
  }

  // 신청을 취소한 뒤 현재 목록을 다시 조회한다
  Future<CancelResult> cancel(int requestId) async {
    if (!_processingIds.add(requestId)) {
      return CancelResult.failed;
    }
    _notify();
    try {
      try {
        await _repository.cancelLeaveRequest(requestId);
      } catch (_) {
        return CancelResult.failed;
      }

      await _fetch();
      return _loadError == null
          ? CancelResult.succeeded
          : CancelResult.succeededRefreshFailed;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  Future<void> retry() => _fetch();

  static bool isCancelable(
    LeaveRequestListItem item, {
    DateTime? now,
  }) {
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
