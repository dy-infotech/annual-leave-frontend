import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:dio/dio.dart';

/// 대시보드 조회 API.
class DashboardRepository {
  DashboardRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  /// 대시보드 조회. GET /api/dashboard
  Future<DashboardData> fetchDashboard() async {
    final response = await _dio.get('/api/dashboard');
    return DashboardData.fromJson(response.data);
  }
}
