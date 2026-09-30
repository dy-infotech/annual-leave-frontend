import 'package:annual_leave_frontend/core/services/fcm_service.dart';
import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';

/// 대시보드 화면(DSH001_M01)의 ViewModel.
///
/// 기존 DashboardProvider에서 FCM 로직을 FcmService로 분리하고
/// 조회 상태만 남긴 것이다.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    DashboardRepository? repository,
    Future<void> Function()? registerFcm,
    Future<void> Function()? refreshSession,
  })  : _repository = repository ?? DashboardRepository(),
        _registerFcm =
            registerFcm ?? FcmService.instance.registerTokenAndListeners,
        _refreshSession = refreshSession ?? _noopRefresh;

  final DashboardRepository _repository;
  final Future<void> Function() _registerFcm;
  final Future<void> Function() _refreshSession;

  static Future<void> _noopRefresh() async {}

  DashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;
  int _requestSeq = 0;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboard() async {
    if (_disposed) return;
    final seq = ++_requestSeq;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Backend 권한은 요청 시점 조직 상태를 사용하므로 메뉴 snapshot도 함께 갱신한다.
      await _refreshSession();
      if (_disposed || seq != _requestSeq) return;
      final data = await _repository.fetchDashboard();
      if (_disposed || seq != _requestSeq) return;
      _data = data;
    } catch (e) {
      if (!_disposed && seq == _requestSeq) {
        _errorMessage = '대시보드 정보를 불러오지 못했습니다.';
      }
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        notifyListeners();

        if (data?.allEmployeeRequestSummary != null) {
          await _registerFcm();
        }
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    super.dispose();
  }
}
