import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';
import '../../../../core/viewmodel/processing_ids_mixin.dart';
import '../../common/model/dto/leave_request_record_dto.dart';
import '../../common/model/api_client/leave_request_common_api_client.dart';
import '../model/api_client/leave_request_list_api_client.dart';

class LeaveRequestListViewModel extends ChangeNotifier with ProcessingIdsMixin {
  final LeaveRequestListApiClient _listApiClient;
  final LeaveRequestCommonApiClient _commonApiClient;
  LeaveRequestListViewModel(this._listApiClient, this._commonApiClient);

  List<LeaveRequestRecordDto> items = [];
  bool isLoading = true;
  String? statusFilter; // null = 전체
  DateTimeRange? dateRange;
  bool showMyRequestsOnly = false; // false = "전체", true = "내 신청"

  // 화면 진입 시 딱 한 번, 라우트로 전달된 초기 필터를 반영해서 불러온다.
  // (기존 코드는 이 초기값을 매 fetch()마다 강제로 되돌려서, 진입 후 드롭다운으로
  //  바꾼 필터가 다시 초기값으로 리셋되는 문제가 있었음 — 여기서는 최초 1회만 적용)
  Future<void> init({String? initialStatus, bool initialShowMyOnly = false}) async {
    statusFilter = initialStatus;
    showMyRequestsOnly = initialShowMyOnly;
    await fetch();
  }

  Future<void> fetch() async {
    isLoading = true;
    notifyListeners();
    try {
      items = showMyRequestsOnly
          ? await _commonApiClient.fetchMyList(status: statusFilter, dateRange: dateRange)
          : await _listApiClient.fetchAllList(status: statusFilter, dateRange: dateRange);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setStatusFilter(String? status) async {
    statusFilter = status;
    await fetch();
  }

  Future<void> setDateRange(DateTimeRange? range) async {
    dateRange = range;
    await fetch();
  }

  Future<void> toggleMode() async {
    showMyRequestsOnly = !showMyRequestsOnly;
    await fetch();
  }

  // 대기 상태 + 본인 신청 건만 취소 가능
  bool isCancelable(LeaveRequestRecordDto item, String? userEmployeeNumber) {
    return item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber;
  }

  Future<bool> cancel(int requestId) async {
    try {
      return await runWithProcessing(requestId, () async {
        await _listApiClient.cancel(requestId);
        await fetch();
        return true;
      });
    } catch (e) {
      return false;
    }
  }
}
