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
  Future<void> Function(int generation)? _unauthorizedHandler;
  int _sessionGeneration = 0;

  int get sessionGeneration => _sessionGeneration;

  void setUnauthorizedHandler(
      Future<void> Function(int generation)? handler) {
    _unauthorizedHandler = handler;
  }

  Future<void> _handleUnauthorized(
      int requestGeneration, String requestToken) async {
    if (requestGeneration != _sessionGeneration) return;

    final currentToken = await getToken();
    if (requestGeneration != _sessionGeneration ||
        currentToken != requestToken) {
      return;
    }

    // delete await 전에 세대를 먼저 올려 같은 세대의 다른 늦은 응답을 무효화한다.
    final expiredGeneration = ++_sessionGeneration;
    await _storage.delete(key: _tokenKey);

    // delete 중 새 로그인 토큰이 저장됐다면 새 세션을 만료시키지 않는다.
    if (expiredGeneration != _sessionGeneration) return;

    final handler = _unauthorizedHandler;
    if (handler != null) {
      await handler(expiredGeneration);
    }
  }

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

    if (kDebugMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final query = options.queryParameters.isEmpty
              ? ''
              : ' query=${options.queryParameters}';
          final body = options.data == null
              ? ''
              : ' body=${_redactForLog(options.data)}';
          debugPrint('[API] ${options.method} ${options.path}$query$body');
          return handler.next(options);
        },
      ));
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final isPublicAuthPath =
            options.path.startsWith('/api/auth/') &&
            options.path != '/api/auth/logout';
        if (!isPublicAuthPath) {
          var authorization = options.headers['Authorization']?.toString();
          if (authorization == null || authorization.isEmpty) {
            final token = await _storage.read(key: _tokenKey);
            if (token != null) {
              authorization = 'Bearer $token';
              options.headers['Authorization'] = authorization;
            }
          }

          if (authorization != null &&
              authorization.startsWith('Bearer ')) {
            options.extra['authGeneration'] = _sessionGeneration;
            options.extra['authToken'] =
                authorization.substring('Bearer '.length);
          }
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        final authenticatedRequest =
            error.requestOptions.headers['Authorization'] != null;
        final skipUnauthorized =
            error.requestOptions.extra['skipUnauthorizedHandling'] == true;

        if (error.response?.statusCode == 401 &&
            authenticatedRequest &&
            !skipUnauthorized) {
          final generation =
              error.requestOptions.extra['authGeneration'] as int?;
          final token = error.requestOptions.extra['authToken'] as String?;
          if (generation != null && token != null) {
            await _handleUnauthorized(generation, token);
          }
        }

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
    ++_sessionGeneration;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() async {
    ++_sessionGeneration;
    await _storage.delete(key: _tokenKey);
  }
}
