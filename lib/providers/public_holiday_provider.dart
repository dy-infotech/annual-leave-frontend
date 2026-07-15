import 'package:flutter/foundation.dart';
import '../models/public_holiday.dart';
import '../services/api_client.dart';

class PublicHolidayProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<PublicHoliday> _currentYearHolidays = [];
  List<PublicHoliday> _nextYearHolidays = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PublicHoliday> get currentYearHolidays => _currentYearHolidays;
  List<PublicHoliday> get nextYearHolidays => _nextYearHolidays;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isHoliday(DateTime day) {
    return [..._currentYearHolidays, ..._nextYearHolidays].any((h) =>
    h.year == day.year && h.month == day.month && h.day == day.day);
  }

  Future<void> fetchPublicHoliday() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responseCurrentYearHolidays = await _apiClient.dio.get('/api/leave-requests/current-year-special-days');
      final responseNextYearHolidays = await _apiClient.dio.get('/api/leave-requests/next-year-special-days');

      _currentYearHolidays = (responseCurrentYearHolidays.data as List)
          .map((e) => PublicHoliday.fromJson(e))
          .toList();

      _nextYearHolidays = (responseNextYearHolidays.data as List)
          .map((e) => PublicHoliday.fromJson(e))
          .toList();

    } catch (e) {
      _errorMessage = '공휴일 정보를 불러오지 못했습니다.';

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
