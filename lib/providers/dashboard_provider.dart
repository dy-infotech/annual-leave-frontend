import 'package:flutter/foundation.dart';
import '../models/dashboard_models.dart';
import '../services/api_client.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

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
      final response = await _apiClient.dio.get('/api/dashboard');
      _data = DashboardData.fromJson(response.data);
    } catch (e) {
      _errorMessage = '대시보드 정보를 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
