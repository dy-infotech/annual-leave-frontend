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

  // 단건 선택 상태 (아무것도 선택되지 않았을 때는 null)
  int? _selectedRequestId;

  List<PendingLeaveRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get selectedRequestId => _selectedRequestId;
  bool get hasSelection => _selectedRequestId != null;
  bool get isProcessing => _processingIds.isNotEmpty;

  PendingLeaveRequest? get selectedRequest {
    if (_selectedRequestId == null) return null;
    return _requests.firstWhere((req) => req.requestId == _selectedRequestId);
  }

  void select(int requestId) {
    _selectedRequestId = requestId;
    notifyListeners();
  }

  Future<void> fetch() async {
    _isLoading = true;
    _errorMessage = null;
    _selectedRequestId = null; // 목록 새로고침 시 선택 상태 초기화
    notifyListeners();
    try {
      _requests = await _repository.fetchPendingLeaveRequests();
    } catch (e) {
      _errorMessage = '목록을 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 승인 처리. 성공 여부를 돌려주며, 성공 시 목록을 재조회한다.
  Future<bool> approve(int requestId) async {
    _processingIds.add(requestId);
    notifyListeners();
    try {
      await _repository.approveLeaveRequest(requestId);
      await fetch();
      return true;
    } catch (e) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      notifyListeners();
    }
  }

  /// 반려 처리. 사유가 빈 문자열이면 null로 전송한다.
  Future<bool> reject(int requestId, String reason) async {
    _processingIds.add(requestId);
    notifyListeners();
    try {
      await _repository.rejectLeaveRequest(
        requestId,
        rejectReason: reason.isEmpty ? null : reason,
      );
      await fetch();
      return true;
    } catch (e) {
      return false;
    } finally {
      _processingIds.remove(requestId);
      notifyListeners();
    }
  }
}
