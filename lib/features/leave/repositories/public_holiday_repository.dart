import 'dart:async';

import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 공휴일(당해년도 + 내년) 조회.
///
/// 캐시는 연도와 TTL을 함께 기록한다. 같은 시점의 중복 호출은 하나의
/// in-flight Future를 공유하고, 당해년도/차년도 API는 병렬 조회한다.
class PublicHolidayRepository {
  PublicHolidayRepository({
    Dio? dio,
    DateTime Function()? now,
    Duration cacheTtl = const Duration(hours: 6),
  })  : _dio = dio ?? ApiClient().dio,
        _now = now ?? DateTime.now,
        _cacheTtl = cacheTtl;

  final Dio _dio;
  final DateTime Function() _now;
  final Duration _cacheTtl;

  static List<PublicHoliday>? _cache;
  static int? _cachedYear;
  static DateTime? _expiresAt;
  static Future<List<PublicHoliday>>? _inFlight;

  Future<List<PublicHoliday>> fetchPublicHolidays({bool refresh = false}) {
    final now = _now();
    final year = now.year;
    final cacheValid = _cache != null &&
        _cachedYear == year &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!);

    if (!refresh && cacheValid) {
      return Future.value(_cache!);
    }

    if (_inFlight != null) {
      return _inFlight!;
    }

    final future = _load(year, now);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<List<PublicHoliday>> _load(int year, DateTime loadedAt) async {
    final responses = await Future.wait([
      _dio.get('/api/leave-requests/current-year-special-days'),
      _dio.get('/api/leave-requests/next-year-special-days'),
    ]);

    final result = <PublicHoliday>[
      ...(responses[0].data as List).map(
        (json) => PublicHoliday.fromJson(Map<String, dynamic>.from(json as Map)),
      ),
      ...(responses[1].data as List).map(
        (json) => PublicHoliday.fromJson(Map<String, dynamic>.from(json as Map)),
      ),
    ];

    // 조회 도중 해가 바뀌었다면 다음 호출이 다시 동기화하도록 캐시하지 않는다.
    if (_now().year == year) {
      _cache = result;
      _cachedYear = year;
      _expiresAt = loadedAt.add(_cacheTtl);
    }
    return result;
  }

  @visibleForTesting
  static void clearCache() {
    _cache = null;
    _cachedYear = null;
    _expiresAt = null;
    _inFlight = null;
  }
}
