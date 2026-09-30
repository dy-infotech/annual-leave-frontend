import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:annual_leave_frontend/core/config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  dynamic _redactForLog(dynamic value) {
    if (value is Map) {
      return value.map((key, item) {
        final normalized = key.toString().toLowerCase();
        final sensitive = normalized.contains('password') ||
            normalized.contains('token') ||
            normalized.contains('email');
        return MapEntry(key, sensitive ? '<redacted>' : _redactForLog(item));
      });
    }
    if (value is List) return value.map(_redactForLog).toList();
    return value;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // 디버그 빌드에서만 요청 내용을 로그로 남긴다.
    // 리팩터링 전후로 같은 시나리오의 요청이 동일한지 비교하는 용도.
    // Authorization 헤더는 남기지 않는다.
    if (kDebugMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final query =
              options.queryParameters.isEmpty ? '' : ' query=${options.queryParameters}';
          final body = options.data == null
              ? ''
              : ' body=${_redactForLog(options.data)}';
          debugPrint('[API] ${options.method} ${options.path}$query$body');
          return handler.next(options);
        },
      ));
    }

    // 요청마다, 저장된 JWT를 자동으로 Authorization 헤더에 할당
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        final responseData = error.response?.data;
        final rawMessage =
            responseData is Map ? responseData['message'] : null;
        final message = rawMessage is String && rawMessage.trim().isNotEmpty
            ? rawMessage
            : responseData is Map
                ? '요청 처리 중 오류가 발생했습니다.'
                : '네트워크 오류가 발생했습니다.';
        error = error.copyWith(message: message);
        return handler.next(error);
      },
    ));
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
