import '../../../../core/network/api_client.dart';
import '../dto/dashboard_dto.dart';

class DashboardApiClient {
  final ApiClient _apiClient;
  DashboardApiClient(this._apiClient);

  Future<DashboardDataDto> fetchDashboard() async {
    final response = await _apiClient.dio.get('/api/dashboard');
    return DashboardDataDto.fromJson(response.data);
  }
}
