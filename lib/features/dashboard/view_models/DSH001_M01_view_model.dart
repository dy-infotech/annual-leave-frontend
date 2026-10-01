import 'package:annual_leave_frontend/core/services/fcm_service.dart';
import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/repositories/dashboard_repository.dart';
import 'package:flutter/foundation.dart';

// 대시보드 조회와 초기 부가 작업 상태를 관리한다
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
      // 대시보드 조회 전 현재 세션 권한을 갱신한다
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
          try {
            await _registerFcm();
          } catch (e) {
            // 알림 등록 실패는 대시보드 조회 결과에 반영하지 않는다
            debugPrint('FCM 등록 실패(대시보드 조회 결과는 유지): $e');
          }
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
