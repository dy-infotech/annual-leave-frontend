import '../../../../core/network/api_client.dart';
import '../dto/public_holiday_dto.dart';

class PublicHolidayApiClient {
  final ApiClient _apiClient;
  PublicHolidayApiClient(this._apiClient);

  Future<List<PublicHolidayDto>> fetchCurrentYear() async {
    final response = await _apiClient.dio.get('/api/leave-requests/current-year-special-days');
    return (response.data as List).map((e) => PublicHolidayDto.fromJson(e)).toList();
  }

  Future<List<PublicHolidayDto>> fetchNextYear() async {
    final response = await _apiClient.dio.get('/api/leave-requests/next-year-special-days');
    return (response.data as List).map((e) => PublicHolidayDto.fromJson(e)).toList();
  }
}
