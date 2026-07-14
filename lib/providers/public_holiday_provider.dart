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

    // ===== 테스트용 임시 데이터 (테스트 끝나면 삭제하고 아래 실제 API 코드로 복원) =====
    await Future.delayed(const Duration(milliseconds: 300)); // 실제 네트워크처럼 약간 지연

    _currentYearHolidays = [
      PublicHoliday(name: '신정', date: DateTime(2026, 7, 1)),
      PublicHoliday(name: '설날', date: DateTime(2026, 7, 16)),
      PublicHoliday(name: '설날', date: DateTime(2026, 7, 17)),
      PublicHoliday(name: '설날', date: DateTime(2026, 8, 18)),
      PublicHoliday(name: '삼일절', date: DateTime(2026, 8, 1)),
      PublicHoliday(name: '어린이날', date: DateTime(2026, 6, 5)),
      PublicHoliday(name: '광복절', date: DateTime(2026, 7, 17)),
    ];

    _nextYearHolidays = [
      PublicHoliday(name: '신정', date: DateTime(2027, 1, 1)),
    ];

    _isLoading = false;
    notifyListeners();
    return;
    // ===== 여기까지 테스트용 =====

    // try {
    //   final responseCurrentYearHolidays = await _apiClient.dio.get('/api/leave-requests/current-year-special-days');
    //   final responseNextYearHolidays = await _apiClient.dio.get('/api/leave-requests/next-year-special-days');
    //
    //   _currentYearHolidays = (responseCurrentYearHolidays.data as List)
    //       .map((e) => PublicHoliday.fromJson(e))
    //       .toList();
    //
    //   _nextYearHolidays = (responseNextYearHolidays.data as List)
    //       .map((e) => PublicHoliday.fromJson(e))
    //       .toList();
    //
    // } catch (e) {
    //   _errorMessage = '공휴일 정보를 불러오지 못했습니다.';
    //
    // } finally {
    //   _isLoading = false;
    //   notifyListeners();
    // }
  }
}
