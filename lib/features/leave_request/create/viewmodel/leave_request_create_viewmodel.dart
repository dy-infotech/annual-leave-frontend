import 'package:flutter/foundation.dart';
import '../../common/model/dto/leave_request_record_dto.dart';
import '../../common/model/api_client/leave_request_common_api_client.dart';
import '../model/dto/leave_request_create_dto.dart';
import '../model/enum/leave_type.dart';
import '../model/api_client/leave_request_create_api_client.dart';
import '../model/service/leave_day_calculator.dart';
import '../model/service/leave_overlap_service.dart';

// 신청 기간이 기존 대기/승인 신청과 겹칠 때 View가 안내 다이얼로그를 띄울 수 있도록
// 구분해서 던지는 예외. (일반 검증 실패는 errorMessage로, 이 경우만 예외로 구분)
class LeaveOverlapException implements Exception {}

class LeaveRequestCreateViewModel extends ChangeNotifier {
  final LeaveRequestCreateApiClient _createApiClient;
  final LeaveRequestCommonApiClient _commonApiClient;
  LeaveRequestCreateViewModel(this._createApiClient, this._commonApiClient);

  DateTime? startDate;
  DateTime? endDate;
  LeaveType selectedLeaveType = LeaveType.full;
  String useDaysText = '0';
  String leaveReason = '';
  bool isSubmitting = false;
  String? errorMessage;

  List<LeaveRequestRecordDto> _myItems = [];

  double get useDays => double.tryParse(useDaysText) ?? 0;

  // 사유 입력란 필요 여부 (연차, 반차 제외한 나머지)
  bool get needsReason => ![LeaveType.full, LeaveType.amHalf, LeaveType.pmHalf].contains(selectedLeaveType);

  // 캘린더 진입 시 한 번 불러와서, 겹침 검사 + 별표 표시에 함께 사용
  Future<void> loadMyItemsForOverlapCheck() async {
    _myItems = await _commonApiClient.fetchMyList();
    notifyListeners();
  }

  bool isRequestedDate(DateTime day) => LeaveOverlapService(_myItems).isRequestedDate(day);

  bool isInRange(DateTime day) {
    if (startDate == null) return false;
    final end = endDate ?? startDate!;
    return !day.isBefore(startDate!) && !day.isAfter(end);
  }

  void selectLeaveType(LeaveType type) {
    final wasHalfDay = selectedLeaveType == LeaveType.amHalf || selectedLeaveType == LeaveType.pmHalf;
    final isHalfDay = type == LeaveType.amHalf || type == LeaveType.pmHalf;

    selectedLeaveType = type;
    if (isHalfDay) {
      useDaysText = '0.5';
    } else if (wasHalfDay) {
      useDaysText = '0';
    }
    notifyListeners();
  }

  void selectDay(DateTime day, {required bool Function(DateTime) isHoliday}) {
    final isHalfDay = selectedLeaveType == LeaveType.amHalf || selectedLeaveType == LeaveType.pmHalf;

    if (isHalfDay) {
      // 반차인 경우 (시작일 = 종료일), 항상 단일 날짜로 선택
      startDate = day;
      endDate = day;
      useDaysText = '0.5';
    } else if (startDate == null || (startDate != null && endDate != null)) {
      // 새로 범위 선택 시작
      startDate = day;
      endDate = null;
      useDaysText = '0';
    } else if (day.isBefore(startDate!)) {
      // 시작일보다 이전 날짜를 누르면 시작일 갱신
      startDate = day;
      useDaysText = '0';
    } else {
      endDate = day;
      useDaysText = calculateUsableDays(startDate!, day, isHoliday).toString();
    }
    notifyListeners();
  }

  int usableDays({required bool Function(DateTime) isHoliday}) {
    if (startDate == null) return 0;
    return calculateUsableDays(startDate!, endDate ?? startDate!, isHoliday);
  }

  // 성공 시 true. 검증 실패 시 errorMessage를 채우고 false.
  // 기간이 겹치면 LeaveOverlapException을 던져서, View가 안내 다이얼로그를 띄우게 한다.
  Future<bool> submit() async {
    if (startDate == null) {
      errorMessage = '날짜를 선택해주세요.';
      notifyListeners();
      return false;
    }
    if (useDays <= 0) {
      errorMessage = '사용일수를 입력해주세요.';
      notifyListeners();
      return false;
    }

    // 제출 직전, 최신 상태로 다시 확인 후 겹침 검사
    await loadMyItemsForOverlapCheck();
    final effectiveEndDate = endDate ?? startDate!;

    if (LeaveOverlapService(_myItems).hasOverlap(startDate!, effectiveEndDate)) {
      throw LeaveOverlapException();
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _createApiClient.create(LeaveRequestCreateDto(
        leaveType: selectedLeaveType.code,
        startDate: startDate!,
        endDate: effectiveEndDate,
        useDays: useDays,
        leaveReason: needsReason ? leaveReason : null,
      ));
      return true;
    } catch (e) {
      errorMessage = '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
