import 'package:flutter/foundation.dart';
import '../models/enums/LeaveState.dart';
import '../services/api_client.dart';
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

  // 휴가 신청 화면에서 선택한 기간(start~end)이 기존 신청(대기(PENDING)/승인(APPROVED))과 겹치는지 확인
  bool hasOverlap(DateTime start, DateTime end) {
    // 시간 정보를 제거하고 순수 날짜(연/월/일)만 남긴 로컬 DateTime으로 정규화
    DateTime normalize(DateTime dateTime) {
      final local = dateTime.toLocal(); // 1. UTC든 로컬이든 로컬 시간대로 통일
      return DateTime(local.year, local.month, local.day); // 2. 시/분/초 제외하고 날짜만 남김
    }

    final normalizedStart = normalize(start);
    final normalizedEnd = normalize(end);

    return _items
        .where((item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code)
        .any((item) {
      final itemStart = normalize(DateTime.parse(item.startDate));
      final itemEnd = normalize(DateTime.parse(item.endDate));
      return !normalizedStart.isAfter(itemEnd) && !normalizedEnd.isBefore(itemStart);
    });
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
}