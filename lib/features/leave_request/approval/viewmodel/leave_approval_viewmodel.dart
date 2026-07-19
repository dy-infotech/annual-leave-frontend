import 'package:flutter/foundation.dart';
import '../../../../core/viewmodel/processing_ids_mixin.dart';
import '../model/dto/pending_leave_request_dto.dart';
import '../model/api_client/leave_approval_api_client.dart';

class LeaveApprovalViewModel extends ChangeNotifier with ProcessingIdsMixin {
  final LeaveApprovalApiClient _apiClient;
  LeaveApprovalViewModel(this._apiClient);

  List<PendingLeaveRequestDto> requests = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> fetchPendingList() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      requests = await _apiClient.fetchPending();
    } catch (e) {
      errorMessage = '목록을 불러오지 못했습니다.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approve(int requestId) async {
    try {
      return await runWithProcessing(requestId, () async {
        await _apiClient.approve(requestId);
        await fetchPendingList();
        return true;
      });
    } catch (e) {
      return false;
    }
  }

  Future<bool> reject(int requestId, String reason) async {
    try {
      return await runWithProcessing(requestId, () async {
        await _apiClient.reject(requestId, reason);
        await fetchPendingList();
        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
