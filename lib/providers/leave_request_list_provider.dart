import 'package:flutter/foundation.dart';
import '../models/enums/LeaveState.dart';
import '../models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import '../models/leave_request_models.dart';

class LeaveRequestListProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<LeaveRequestListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 내 휴가 신청 목록 조회
  Future<void> fetchMyLeaveRequestList() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.dio.get('/api/leave-requests/my');

      _items = (response.data as List)
          .map((json) => LeaveRequestListItem.fromJson(json))
          .toList();

    } catch (e) {
      _errorMessage = '휴가 신청 목록을 불러오지 못했습니다.';

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 새 신청의 기간(start~end)과 종류(newLeaveType)가 기존 신청과 겹치는지 확인
  bool hasOverlap(DateTime start, DateTime end, String newLeaveType) {
    // 시간 정보를 제거하고 순수 날짜(연/월/일)만 남긴 로컬 DateTime으로 정규화
    DateTime normalize(DateTime dateTime) {
      final local = dateTime.toLocal(); // 1. UTC든 로컬이든 로컬 시간대로 통일
      return DateTime(local.year, local.month, local.day);  // 2. 시/분/초 제외하고 날짜만 남김
    }

    final normalizedStart = normalize(start);
    final normalizedEnd = normalize(end);

    return _items
        .where((item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code)
        .any((item) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));

      // 1. 날짜 범위가 안 겹치면 무조건 겹침 아님
      final dateOverlaps = !normalizedStart.isAfter(itemEnd) && !normalizedEnd.isBefore(itemStart);
      if (!dateOverlaps) return false;

      // 2. 날짜는 겹치는데, 둘 다 반차이고 오전/오후가 서로 다르면 겹침 아님
      // (예: 기존 오전 반차 + 신규 오후 반차 -> 허용)
      if (_isHalf(newLeaveType) && _isHalf(item.leaveType)) {
        // 서로 다른 반차 시간대면 겹치지 않음
        if (newLeaveType != item.leaveType) return false;
      }

      // 그 외(종일이 하나라도 끼거나, 같은 시간대 반차끼리)는 겹침
      return true;
    });
  }

  // 반차(오전/오후) 여부
  bool _isHalf(String leaveType) {
    return (leaveType == LeaveType.amHalf.code) || (leaveType == LeaveType.pmHalf.code);
  }

  // 캘린더에 별표 표시할 날짜인지 확인 (대기/승인 상태만)
  bool isRequestedDate(DateTime dateTime) {
    DateTime normalize(DateTime dateTime) {
      final local = dateTime.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final target = normalize(dateTime);

    return _items
        .where((item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code)
        .any((item) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));
      return !target.isBefore(itemStart) && !target.isAfter(itemEnd);
    });
  }

  // 특정 날짜의 휴가 신청 상태 (오전/오후 각각의 상태)
  // 반환값 status: null(없음) / 'PENDING' / 'APPROVED'
  ({String? amStatus, String? pmStatus}) halfDayStatus(DateTime dateTime) {
    DateTime normalize(DateTime d) {
      final local = d.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final target = normalize(dateTime);
    String? amStatus;
    String? pmStatus;

    for (final item in _items.where((item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code)) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));
      final inRange = !target.isBefore(itemStart) && !target.isAfter(itemEnd);
      if (!inRange) continue;

      if (item.leaveType == LeaveType.amHalf.code) {
        // 오전
        amStatus = item.status;
      } else if (item.leaveType == LeaveType.pmHalf.code) {
        // 오후
        pmStatus = item.status;
      } else {
        // 종일 등 반차가 아닌 신청은 오전/오후 모두 점유
        amStatus = item.status;
        pmStatus = item.status;
      }
    }

    return (amStatus: amStatus, pmStatus: pmStatus);
  }
}