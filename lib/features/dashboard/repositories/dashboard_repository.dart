import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:dio/dio.dart';

// 대시보드 조회 요청을 담당한다
class DashboardRepository {
  DashboardRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // 현재 사용자의 대시보드 정보를 조회한다
  Future<DashboardData> fetchDashboard() async {
    final response = await _dio.authenticatedGet('/api/dashboard');
    return DashboardData.fromJson(response.data);
  }
}
