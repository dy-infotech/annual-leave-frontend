import 'package:flutter/foundation.dart';
import '../model/dto/dashboard_dto.dart';
import '../model/api_client/dashboard_api_client.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardApiClient _apiClient;
  DashboardViewModel(this._apiClient);

  DashboardDataDto? data;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchDashboard() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      data = await _apiClient.fetchDashboard();
    } catch (e) {
      errorMessage = '대시보드 정보를 불러오지 못했습니다.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
