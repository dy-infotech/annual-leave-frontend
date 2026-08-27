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
  })  : _repository = repository ?? DashboardRepository(),
        _registerFcm =
            registerFcm ?? FcmService.instance.registerTokenAndListeners;

  final DashboardRepository _repository;
  final Future<void> Function() _registerFcm;

  DashboardData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  DashboardData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _repository.fetchDashboard();
    } catch (e) {
      _errorMessage = '대시보드 정보를 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();

      // 관리자 대시보드 조회에 성공한 경우에만 FCM 등록/구독 수행 (기존 동작 유지)
      if (data?.allEmployeeRequestSummary != null) {
        await _registerFcm();
      }
    }
  }
}
