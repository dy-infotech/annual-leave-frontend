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
    return _items
        .where((item) => item.status == LeaveState.pending.code || item.status == LeaveState.approved.code)
        .any((item) {
      final itemStart = DateTime.parse(item.startDate);
      final itemEnd = DateTime.parse(item.endDate);
      return !start.isAfter(itemEnd) && !end.isBefore(itemStart);
    });
  }
}