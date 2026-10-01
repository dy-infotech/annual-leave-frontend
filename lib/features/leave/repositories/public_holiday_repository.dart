import 'dart:async';

import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// 현재 연도와 다음 연도 공휴일을 조회하고 캐시한다
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
  static final Map<int, Future<List<PublicHoliday>>> _inFlightByYear = {};

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

    final inFlight = _inFlightByYear[year];
    if (inFlight != null) {
      return inFlight;
    }

    late Future<List<PublicHoliday>> future;
    future = _load(year, now).whenComplete(() {
      if (identical(_inFlightByYear[year], future)) {
        _inFlightByYear.remove(year);
      }
    });
    _inFlightByYear[year] = future;
    return future;
  }

  Future<List<PublicHoliday>> _load(int year, DateTime loadedAt) async {
    final responses = await Future.wait([
      _dio.authenticatedGet('/api/leave-requests/current-year-special-days'),
      _dio.authenticatedGet('/api/leave-requests/next-year-special-days'),
    ]);

    final result = <PublicHoliday>[
      ...(responses[0].data as List).map(
        (json) =>
            PublicHoliday.fromJson(Map<String, dynamic>.from(json as Map)),
      ),
      ...(responses[1].data as List).map(
        (json) =>
            PublicHoliday.fromJson(Map<String, dynamic>.from(json as Map)),
      ),
    ];

    // 조회 중 연도가 바뀌면 결과를 캐시하지 않는다
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
    _inFlightByYear.clear();
  }
}
