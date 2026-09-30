import 'dart:async';

import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:annual_leave_frontend/core/network/browser_credentials.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef UnauthorizedHandler = Future<void> Function(int generation);

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const _tokenKey = 'annual_leave_access_token';
  static const _authGenerationKey = 'authGeneration';
  static const _authRetriedKey = 'authRetried';
  static const _refreshSkew = Duration(seconds: 45);

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  UnauthorizedHandler? _unauthorizedHandler;
  bool _sessionExpired = false;
  int _authGeneration = 0;
  Future<void> _tokenMutation = Future<void>.value();
  Future<LoginResponse?>? _refreshInFlight;

  int get sessionGeneration => _authGeneration;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    configureBrowserCredentials(dio);

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

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _attachCurrentAuthentication(options);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final requestGeneration =
            response.requestOptions.extra[_authGenerationKey] as int?;
        if (requestGeneration != null && requestGeneration != _authGeneration) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.cancel,
              message: '로그인 세션이 변경되어 이전 응답을 무시합니다.',
            ),
          );
        }
        return handler.next(response);
      },
      onError: (DioException error, handler) async {
        final requestGeneration =
            error.requestOptions.extra[_authGenerationKey] as int?;

        if (error.response?.statusCode == 401 &&
            requestGeneration != null &&
            requestGeneration == _authGeneration &&
            !_isAuthenticationRequest(error.requestOptions) &&
            error.requestOptions.extra[_authRetriedKey] != true) {
          try {
            final refreshed = await _refreshAccessTokenSingleFlight(
              requestGeneration,
              await _storage.read(key: _tokenKey),
            );
            if (refreshed != null && requestGeneration == _authGeneration) {
              final retry = error.requestOptions;
              retry.extra[_authRetriedKey] = true;
              await _attachCurrentAuthentication(retry);
              final response = await dio.fetch<dynamic>(retry);
              return handler.resolve(response);
            }
          } on DioException {
            // 네트워크/서버 장애는 세션 폐기로 오인하지 않는다.
          }
        }

        final message = _responseMessage(error) ??
            (error.type == DioExceptionType.cancel
                ? error.message ?? '요청이 취소되었습니다.'
                : '네트워크 오류가 발생했습니다.');
        return handler.next(error.copyWith(message: message));
      },
    ));
  }

  void setUnauthorizedHandler(UnauthorizedHandler? handler) {
    _unauthorizedHandler = handler;
  }

  Future<void> _attachCurrentAuthentication(RequestOptions options) async {
    while (true) {
      final barrier = _tokenMutation;
      await barrier;

      if (_isAuthenticationRequest(options)) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
        return;
      }

      final generation = _authGeneration;
      var token = await _storage.read(key: _tokenKey);
      if (generation != _authGeneration || barrier != _tokenMutation) continue;

      if (token != null && _isExpiringSoon(token)) {
        try {
          final refreshed =
              await _refreshAccessTokenSingleFlight(generation, token);
          if (refreshed != null) {
            token = refreshed.token;
          } else {
            token = await _storage.read(key: _tokenKey);
          }
        } on DioException {
          if (_isExpired(token)) rethrow;
        }
      }

      if (generation != _authGeneration) continue;

      if (token == null) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
      } else {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_authGenerationKey] = generation;
      }
      return;
    }
  }

  bool _isAuthenticationRequest(RequestOptions options) {
    return options.path.startsWith('/api/auth/');
  }

  Future<LoginResponse?> _refreshAccessTokenSingleFlight(
    int expectedGeneration,
    String? beforeToken,
  ) {
    if (expectedGeneration != _authGeneration) {
      return Future<LoginResponse?>.value(null);
    }

    final existing = _refreshInFlight;
    if (existing != null) return existing;

    late Future<LoginResponse?> future;
    future = _performRefresh(expectedGeneration, beforeToken).whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = future;
    return future;
  }

  Future<LoginResponse?> _performRefresh(
    int expectedGeneration,
    String? beforeToken,
  ) async {
    Response<dynamic> response;
    try {
      response = await dio.post(
        '/api/auth/refresh',
        options: Options(headers: const {'X-SSO-Refresh': '1'}),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final sharedToken = await _storage.read(key: _tokenKey);
        if (sharedToken != null &&
            sharedToken != beforeToken &&
            !_isExpired(sharedToken)) {
          return LoginResponse.tryFromAccessToken(sharedToken);
        }

        try {
          response = await dio.post(
            '/api/auth/refresh',
            options: Options(headers: const {'X-SSO-Refresh': '1'}),
          );
        } on DioException catch (retryError) {
          return _handleRefreshFailure(retryError, expectedGeneration);
        }
      } else {
        return _handleRefreshFailure(error, expectedGeneration);
      }
    }

    final refreshed =
        LoginResponse.fromJson(Map<String, dynamic>.from(response.data as Map));
    final replaced =
        await _replaceAccessToken(refreshed.token, expectedGeneration);
    if (!replaced) return null;
    return refreshed;
  }

  Future<LoginResponse?> _handleRefreshFailure(
    DioException error,
    int expectedGeneration,
  ) async {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      await _expireSessionOnce(expectedGeneration);
      return null;
    }
    throw error;
  }

  Future<bool> _replaceAccessToken(
    String token,
    int expectedGeneration,
  ) async {
    var replaced = false;
    await _mutateToken(() async {
      if (expectedGeneration != _authGeneration || _sessionExpired) return;
      await _storage.write(key: _tokenKey, value: token);
      replaced = true;
    });
    return replaced;
  }

  Future<LoginResponse?> restoreSession() async {
    await _tokenMutation;
    final generation = _authGeneration;
    final token = await _storage.read(key: _tokenKey);
    if (token != null && !_isExpiringSoon(token)) {
      return LoginResponse.tryFromAccessToken(token);
    }

    try {
      return await _refreshAccessTokenSingleFlight(generation, token);
    } on DioException {
      if (token != null && !_isExpired(token)) {
        return LoginResponse.tryFromAccessToken(token);
      }
      rethrow;
    }
  }

  Future<void> logoutSession({String? fcmToken}) async {
    try {
      await dio.post(
        '/api/auth/logout',
        data: fcmToken == null ? null : {'fcmToken': fcmToken},
        options: Options(headers: const {'X-SSO-Refresh': '1'}),
      );
    } on DioException {
      // 서버 revoke 실패와 무관하게 이 브라우저는 명시적 로그아웃 상태로 전환한다.
    } finally {
      await _markExplicitLogout();
    }
  }

  Future<void> saveToken(String token) async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      await _storage.write(key: _tokenKey, value: token);
    });
  }

  Future<String?> getToken() async {
    await _tokenMutation;
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      await _storage.delete(key: _tokenKey);
    });
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

  bool _isExpiringSoon(String token) {
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    if (expiresAt == null) return true;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(_refreshSkew));
  }

  bool _isExpired(String? token) {
    if (token == null) return true;
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    return expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc());
  }

  String? _responseMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['message', 'detail']) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return '요청 처리 중 오류가 발생했습니다.';
    }
    return null;
  }

  Future<void> _mutateToken(Future<void> Function() action) async {
    final previous = _tokenMutation;
    final completer = Completer<void>();
    _tokenMutation = completer.future;
    await previous;
    try {
      await action();
    } finally {
      completer.complete();
    }
  }

  Future<void> _expireSessionOnce(int expectedGeneration) async {
    int? expiredGeneration;
    await _mutateToken(() async {
      if (_sessionExpired || expectedGeneration != _authGeneration) return;
      _sessionExpired = true;
      expiredGeneration = ++_authGeneration;
      await _storage.delete(key: _tokenKey);
    });

    final generation = expiredGeneration;
    if (generation != null && generation == _authGeneration) {
      await _unauthorizedHandler?.call(generation);
    }
  }

  Future<void> _markExplicitLogout() async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      await _storage.delete(key: _tokenKey);
    });
  }
}
