import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/foundation.dart';

/// 결재 대기 목록 화면(LVE003_M01)의 ViewModel.
class PendingApprovalViewModel extends ChangeNotifier {
  PendingApprovalViewModel({LeaveRepository? repository})
      : _repository = repository ?? LeaveRepository();

  final LeaveRepository _repository;

  List<PendingLeaveRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _processingIds = {};
  int _requestSeq = 0;
  bool _disposed = false;
  int? _selectedRequestId;

  List<PendingLeaveRequest> get requests => _requests;
  bool get isLoading => _isLoading;
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
    _errorMessage = null;
    _selectedRequestId = null;
    _notify();
    try {
      final requests = await _repository.fetchPendingLeaveRequests();
      if (_disposed || seq != _requestSeq) return;
      _requests = requests;
    } catch (_) {
      if (_disposed || seq != _requestSeq) return;
      _errorMessage = '목록을 불러오지 못했습니다.';
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> approve(int requestId) async {
    _processingIds.add(requestId);
    _notify();
    try {
      await _repository.approveLeaveRequest(requestId);
      await fetch();
      return true;
    } catch (_) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  Future<bool> reject(int requestId, String reason) async {
    _processingIds.add(requestId);
    _notify();
    try {
      await _repository.rejectLeaveRequest(
        requestId,
        rejectReason: reason.isEmpty ? null : reason,
      );
      await fetch();
      return true;
    } catch (_) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
