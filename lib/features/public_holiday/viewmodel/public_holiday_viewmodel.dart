import 'package:flutter/foundation.dart';
import '../model/dto/public_holiday_dto.dart';
import '../model/api_client/public_holiday_api_client.dart';

// 로그인/자동로그인 직후 View가 한 번 호출해서 채우고, leave_request_create
// 화면이 구독해서 캘린더에 공휴일을 표시하는 데 쓰는 전역 상태.
class PublicHolidayViewModel extends ChangeNotifier {
  final PublicHolidayApiClient _apiClient;
  PublicHolidayViewModel(this._apiClient);

  List<PublicHolidayDto> _currentYearHolidays = [];
  List<PublicHolidayDto> _nextYearHolidays = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isHoliday(DateTime day) {
    return [..._currentYearHolidays, ..._nextYearHolidays]
        .any((h) => h.year == day.year && h.month == day.month && h.day == day.day);
  }

  Future<void> fetchPublicHoliday() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentYearHolidays = await _apiClient.fetchCurrentYear();
      _nextYearHolidays = await _apiClient.fetchNextYear();
    } catch (e) {
      _errorMessage = '공휴일 정보를 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
