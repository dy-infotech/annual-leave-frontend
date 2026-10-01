import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/foundation.dart';

enum ApprovalMutationResult { failed, succeeded, succeededRefreshFailed }

class PendingApprovalViewModel extends ChangeNotifier {
  PendingApprovalViewModel({LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final LeaveRepository _repository;
  static const int _pageSize = LeaveRepository.defaultPageSize;

  List<PendingLeaveRequest> _requests = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  String? _cursorCreatedAt;
  int? _cursorRequestId;
  String? _errorMessage;
  final Set<int> _processingIds = {};
  int _requestSeq = 0;
  bool _disposed = false;
  int? _selectedRequestId;

  List<PendingLeaveRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  int get totalCount => _totalCount;
  String? get errorMessage => _errorMessage;
  int? get selectedRequestId => _selectedRequestId;
  bool get hasSelection => _selectedRequestId != null;
  bool get isProcessing => _processingIds.isNotEmpty;

  PendingLeaveRequest? get selectedRequest {
    final id = _selectedRequestId;
    if (id == null) return null;
    for (final request in _requests) {
      if (request.requestId == id) return request;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void select(int requestId) {
    _selectedRequestId = requestId;
    _notify();
  }

  Future<void> fetch() async {
    final seq = ++_requestSeq;
    _isLoading = true;
    _isLoadingMore = false;
    _requests = [];
    _hasMore = false;
    _totalCount = 0;
    _cursorCreatedAt = null;
    _cursorRequestId = null;
    _errorMessage = null;
    _selectedRequestId = null;
    _notify();

    try {
      final page = await _repository.fetchPendingLeaveRequestsPage(
        page: 0,
        size: _pageSize,
      );
      if (_disposed || seq != _requestSeq) return;
      _requests = page.items;
      _totalCount = page.totalCount;
      _applyPageCursor(page.items, page.hasMore);
    } catch (_) {
      if (_disposed || seq != _requestSeq) return;
      _errorMessage = '목록을 불러오지 못했습니다.';
      _hasMore = false;
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_disposed || _isLoading || _isLoadingMore || !_hasMore || _errorMessage != null) return;
     final seq = _requestSeq;
    _isLoadingMore = true;
    _notify();
    try {
      final page = await _repository.fetchPendingLeaveRequestsPage(
        page: 0,
        size: _pageSize,
        cursorCreatedAt: _cursorCreatedAt,
        cursorRequestId: _cursorRequestId,
      );
      if (_disposed || seq != _requestSeq) return;
      final existingIds = _requests.map((item) => item.requestId).toSet();
      _requests.addAll(
          page.items.where((item) => existingIds.add(item.requestId)));
      _totalCount = page.totalCount;
      _applyPageCursor(page.items, page.hasMore);
    } catch (_) {
      if (!_disposed && seq == _requestSeq) {
        _errorMessage = '추가 목록을 불러오지 못했습니다.';
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
      List<PendingLeaveRequest> page, bool hasMore) {
    _hasMore = hasMore;
    if (page.isNotEmpty) {
      final last = page.last;
      _cursorCreatedAt = last.createdAt;
      _cursorRequestId = last.requestId;
    }
  }

  Future<ApprovalMutationResult> approve(int requestId) async {
    if (_processingIds.contains(requestId)) return ApprovalMutationResult.failed;
    _processingIds.add(requestId);
    _notify();
    try {
      await _repository.approveLeaveRequest(requestId);
      await fetch();
      return _errorMessage == null
          ? ApprovalMutationResult.succeeded
          : ApprovalMutationResult.succeededRefreshFailed;
    } catch (_) {
      return ApprovalMutationResult.failed;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  Future<ApprovalMutationResult> reject(int requestId, String reason) async {
    if (_processingIds.contains(requestId)) return ApprovalMutationResult.failed;
    _processingIds.add(requestId);
    _notify();
    try {
      await _repository.rejectLeaveRequest(
        requestId,
        rejectReason: reason.isEmpty ? null : reason,
      );
      await fetch();
      return _errorMessage == null
          ? ApprovalMutationResult.succeeded
          : ApprovalMutationResult.succeededRefreshFailed;
    } catch (_) {
      return ApprovalMutationResult.failed;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    super.dispose();
  }
}
