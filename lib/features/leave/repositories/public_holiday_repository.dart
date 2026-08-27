import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 공휴일(당해년도 + 내년) 조회.
///
/// 기존 PublicHolidayProvider가 로그인 시 1회 조회해 앱 전역에 보관하던
/// 동작에 대응해, 성공한 조회 결과를 메모리에 캐시하고 재사용한다.
class PublicHolidayRepository {
  PublicHolidayRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  static List<PublicHoliday>? _cache;

  Future<List<PublicHoliday>> fetchPublicHolidays({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache!;

    final responseCurrentYearHolidays =
        await _dio.get('/api/leave-requests/current-year-special-days');
    final responseNextYearHolidays =
        await _dio.get('/api/leave-requests/next-year-special-days');

    _cache = [
      ...(responseCurrentYearHolidays.data as List)
          .map((e) => PublicHoliday.fromJson(e)),
      ...(responseNextYearHolidays.data as List)
          .map((e) => PublicHoliday.fromJson(e)),
    ];
    return _cache!;
  }

  @visibleForTesting
  static void clearCache() => _cache = null;
}
