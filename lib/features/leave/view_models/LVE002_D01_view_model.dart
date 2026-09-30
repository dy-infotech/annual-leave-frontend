import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:flutter/foundation.dart';

/// 휴가 신청 상세 화면(LVE002_D01)의 ViewModel.
class LeaveRequestDetailViewModel extends ChangeNotifier {
  LeaveRequestDetailViewModel({
    required this.requestId,
    LeaveRepository? repository,
  }) : _repository = repository ?? LeaveRepository();

  final int requestId;
  final LeaveRepository _repository;

  LeaveRequestDetail? _detail;
  bool _isLoading = true;
  String? _errorMessage;

  LeaveRequestDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _detail = await _repository.fetchLeaveRequestDetail(requestId);
    } catch (e) {
      _errorMessage = '상세 정보를 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
