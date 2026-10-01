import 'dart:async';

import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:annual_leave_frontend/core/network/browser_credentials.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 세션 만료가 확정됐을 때 호출되는 콜백.
///
/// [generation]은 만료가 확정된 시점의 세션 세대 번호([ApiClient.sessionGeneration])다.
/// 콜백을 받는 쪽은 이 값이 현재 세대와 같을 때만 로그인 화면으로 보내야 한다.
typedef UnauthorizedHandler = Future<void> Function(int generation);

/// 앱 전체가 공유하는 HTTP 클라이언트(Dio 싱글턴)이자 액세스 토큰 수명주기 관리자.
///
/// 책임
/// - 요청마다 저장된 액세스 토큰(JWT)을 `Authorization` 헤더로 붙인다.
///   `/api/auth/` 하위 경로(로그인, 갱신, 로그아웃 등)에는 토큰을 붙이지 않는다.
/// - 만료 45초 전부터는 요청 전에 미리 갱신하고, 401을 받으면 1회 갱신 후 재시도한다.
///   갱신은 `/api/auth/refresh`로 수행하며 refresh 토큰은 브라우저 쿠키로 전달된다
///   ([configureBrowserCredentials] 참고).
/// - 서버 오류 응답의 message를 `DioException.message`에 담아 화면이 그대로 보여줄 수 있게 한다.
///
/// 동시성 설계 (수정 시 반드시 유지할 것)
/// - [_authGeneration]: 로그인/로그아웃/만료/토큰 삭제 때마다 증가하는 "세션 세대" 번호.
///   요청은 전송 시점의 세대를 `extra`에 싣고, 응답이나 401이 돌아왔을 때 세대가 달라졌으면
///   이전 세션의 결과로 보고 버린다. (계정 전환 직후 이전 계정의 응답이 섞이는 것을 막는다)
///   AuthSession의 `_generation`과는 별개의 카운터이므로 서로 비교하지 않는다.
/// - [_tokenMutation]: 토큰 저장소를 바꾸는 작업을 한 줄로 세우는 락 역할의 Future 체인.
///   요청은 이 체인이 비기를 기다린 뒤에 토큰을 읽는다.
/// - [_refreshInFlight]: 여러 요청이 동시에 갱신을 시도해도 실제 호출은 1번만 하는 single-flight.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  /// 보안 저장소에 액세스 토큰을 저장하는 키.
  static const _tokenKey = 'annual_leave_access_token';
  static const _explicitLogoutKey = 'annual_leave_explicit_logout';
  static const _authGenerationKey = 'authGeneration';

  /// `RequestOptions.extra`에서 401 후 재시도를 이미 했는지 표시하는 키. (무한 재시도 방지)
  static const _authRetriedKey = 'authRetried';

  /// 만료 이 시간 전부터는 "곧 만료"로 보고 미리 갱신한다. (기기 시계 오차와 요청 지연 여유분)
  static const _refreshSkew = Duration(seconds: 45);

  /// 모든 Repository가 공유하는 Dio. 인터셉터는 생성자에서 한 번만 등록된다.
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  UnauthorizedHandler? _unauthorizedHandler;

  /// 세션 만료 처리를 이미 했는지 여부. 만료 콜백이 중복 호출되거나,
  /// 만료 직후 늦게 끝난 갱신이 토큰을 다시 저장하는 것을 막는다. 다음 로그인에서 해제된다.
  bool _sessionExpired = false;
  bool _explicitlyLoggedOut = false;
  int _authGeneration = 0;
  Future<void> _tokenMutation = Future<void>.value();
  Future<LoginResponse?>? _refreshInFlight;

  /// 현재 세션 세대 번호. 로그인, 로그아웃, 만료 때마다 증가한다.
  int get sessionGeneration => _authGeneration;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    configureBrowserCredentials(dio);

    // 디버그 빌드에서만 요청 내용을 콘솔에 남긴다. (민감 필드는 마스킹, Authorization 헤더는 출력하지 않음)
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
      // 요청 직전: 토큰 첨부(필요하면 선제 갱신 포함)
      onRequest: (options, handler) async {
        await _attachCurrentAuthentication(options);
        return handler.next(options);
      },
      // 응답 도착: 요청 후 세션이 바뀌었다면(로그아웃/계정 전환) 이전 세션의 응답이므로 버린다.
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
      // 오류: 401이면 토큰을 1회 갱신해 같은 요청을 재시도하고, 그 외에는 메시지를 정리해 전달한다.
      onError: (DioException error, handler) async {
        final requestGeneration =
            error.requestOptions.extra[_authGenerationKey] as int?;

        // 재시도 조건: 현재 세션에서 보낸 인증 요청이 401을 받았고, 아직 재시도한 적이 없을 때
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
            // (원래의 401 오류를 그대로 전달한다. 세션 만료 확정은 _handleRefreshFailure에서만 한다)
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

  /// 세션 만료 확정 시 호출할 콜백을 등록한다. (앱 루트에서 로그인 화면 이동에 사용)
  void setUnauthorizedHandler(UnauthorizedHandler? handler) {
    _unauthorizedHandler = handler;
  }

  /// [options]에 현재 세션의 액세스 토큰을 붙인다.
  ///
  /// 토큰 변경 작업이 진행 중이면 끝나기를 기다리고, 토큰을 읽는 동안 세션 세대가 바뀌거나
  /// 새 변경 작업이 시작되면 처음부터 다시 읽는다. (반쯤 갱신된 상태의 토큰을 쓰지 않기 위함)
  /// 토큰이 없으면 헤더를 붙이지 않고, 있으면 전송 시점의 세션 세대를 `extra`에 기록한다.
  Future<void> _attachCurrentAuthentication(RequestOptions options) async {
    while (true) {
      final barrier = _tokenMutation;
      await barrier;

      if (_isAuthenticationRequest(options)) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
        return;
      }

      if (_explicitlyLoggedOut) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
        return;
      }

      final generation = _authGeneration;
      var token = await _storage.read(key: _tokenKey);
      if (generation != _authGeneration || barrier != _tokenMutation) continue;

      // 만료 임박 토큰은 요청 전에 갱신한다.
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
          // 갱신이 일시 장애로 실패해도 아직 만료 전이면 기존 토큰으로 계속 진행한다.
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

  /// 인증 자체를 다루는 요청인지 여부. `/api/auth/` 하위(로그인, 등록, 갱신, 로그아웃 등)는
  /// 액세스 토큰 없이 호출되며, 401이어도 갱신 후 재시도하지 않는다.
  bool _isAuthenticationRequest(RequestOptions options) {
    return options.path.startsWith('/api/auth/');
  }

  /// 액세스 토큰 갱신을 single-flight로 수행한다.
  ///
  /// 이미 진행 중인 갱신이 있으면 그 결과를 같이 기다린다.
  /// [expectedGeneration]이 현재 세대와 다르면(그 사이 로그아웃/재로그인) 갱신하지 않고 null을 돌려준다.
  /// [beforeToken]은 갱신을 시도하기 직전의 토큰으로, 409 충돌 시 다른 탭의 갱신 여부를 판단하는 데 쓴다.
  ///
  /// 반환: 갱신된 로그인 정보. 세션이 만료 처리됐거나 세대가 바뀌었으면 null.
  /// 네트워크/서버 장애는 DioException으로 전파된다.
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

  /// `/api/auth/refresh`를 실제로 호출해 새 액세스 토큰을 받아 저장한다.
  ///
  /// 서버가 409(갱신 충돌)로 응답하면 다른 탭이 같은 refresh 쿠키로 먼저 갱신 중인 것으로 보고,
  /// 200ms 후 저장소를 다시 읽어 다른 탭이 저장한 새 토큰이 있으면 그것을 쓰고,
  /// 없으면 한 번만 더 요청한다. 401/403은 세션 만료로 처리한다.
  Future<LoginResponse?> _performRefresh(
    int expectedGeneration,
    String? beforeToken,
  ) async {
    Response<dynamic> response;
    try {
      // X-SSO-Refresh 헤더는 서버의 SSO 갱신 요청 규약이다. 제거하면 갱신이 거부될 수 있다.
      response = await dio.post(
        '/api/auth/refresh',
        options: Options(headers: const {'X-SSO-Refresh': '1'}),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // 다른 탭이 이미 새 토큰을 저장했다면 중복 갱신하지 않고 그 토큰을 쓴다.
        final sharedToken = await _storage.read(key: _tokenKey);
        if (sharedToken != null &&
            sharedToken != beforeToken &&
            !_isExpired(sharedToken)) {
          final sharedSession = LoginResponse.tryFromAccessToken(sharedToken);
          if (!_sameSubject(beforeToken, sharedSession)) {
            await _expireSessionOnce(expectedGeneration);
            return null;
          }
          return sharedSession;
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

    // 브라우저가 늦게 도착한 다른 로그인 응답의 HttpOnly refresh cookie를
    // 적용했더라도 현재 access-token 사용자와 다른 계정으로 조용히 전환하지 않는다.
    if (!_sameSubject(beforeToken, refreshed)) {
      await _expireSessionOnce(expectedGeneration);
      return null;
    }

    final replaced =
        await _replaceAccessToken(refreshed.token, expectedGeneration);
    if (!replaced) return null;
    return refreshed;
  }

  bool _sameSubject(String? beforeToken, LoginResponse? candidate) {
    if (beforeToken == null || candidate == null) return true;

    final before = LoginResponse.tryFromAccessToken(beforeToken);
    final beforeEmployeeId = before?.employeeId;
    final candidateEmployeeId = candidate.employeeId;
    if (beforeEmployeeId == null || candidateEmployeeId == null) return true;

    return beforeEmployeeId == candidateEmployeeId;
  }

  /// 갱신 실패를 분류한다. 401/403은 refresh 쿠키가 무효라는 뜻이므로 세션을 만료 처리하고 null을 돌려준다.
  /// 그 외(네트워크 오류, 5xx 등)는 일시 장애일 수 있으므로 세션을 유지한 채 예외를 다시 던진다.
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

  /// 갱신된 토큰을 저장한다. 갱신 도중 로그아웃/만료로 세대가 바뀌었거나 세션이 이미 만료됐다면
  /// 저장하지 않고 false를 돌려준다. (로그아웃한 뒤에 토큰이 되살아나는 것을 막는다)
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

  /// 앱 시작 시 기존 로그인 상태를 복원한다. (자동 로그인)
  ///
  /// 저장된 토큰이 아직 충분히 유효하면 그대로 쓰고, 없거나 곧 만료되면 refresh 쿠키로 갱신을 시도한다.
  /// 반환: 복원된 로그인 정보. 로그인 상태가 아니면(갱신 거부 포함) null.
  /// 갱신이 네트워크/서버 장애로 실패하고 기존 토큰도 이미 만료됐다면 DioException을 던진다.
  Future<LoginResponse?> restoreSession() async {
    await _tokenMutation;
    final generation = _authGeneration;
    final explicitLogout = await _storage.read(key: _explicitLogoutKey);
    if (explicitLogout == '1') {
      _explicitlyLoggedOut = true;
      return null;
    }

    _explicitlyLoggedOut = false;
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

  /// 명시적 로그아웃. 서버에 refresh 토큰 폐기(와 선택적으로 FCM 토큰 해제)를 요청한 뒤
  /// 이 기기의 토큰과 세션 상태를 항상 정리한다. 서버 요청이 실패해도 로컬 로그아웃은 완료된다.
  Future<void> logoutSession({String? fcmToken}) async {
    // 네트워크/FCM 정리보다 로컬 세션 종료를 먼저 확정한다.
    await _markExplicitLogout();

    // old refresh cookie revoke는 즉시 시작하되 화면 전환을 막지 않는다.
    unawaited(_revokeLoggedOutSession(fcmToken: fcmToken));
  }

  Future<void> _revokeLoggedOutSession({String? fcmToken}) async {
    try {
      await dio.post(
        '/api/auth/logout',
        data: fcmToken == null ? null : {'fcmToken': fcmToken},
        options: Options(
          headers: const {
            'X-SSO-Refresh': '1',
            'X-SSO-Background-Logout': '1',
          },
        ),
      );
    } on DioException {
      // explicit logout 표식이 남아 있으므로 서버 revoke 실패가 자동 재로그인으로 이어지지 않는다.
    }
  }

  /// 로그인 성공 후 새 액세스 토큰을 저장한다. 세션 세대를 올려 이전 세션의 진행 중 요청을 무효화하고
  /// 만료 상태를 해제한다.
  Future<void> saveToken(String token) async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      _explicitlyLoggedOut = false;
      // 새 로그인은 이전 explicit-logout 표식을 먼저 해제한 뒤 새 access token을 저장한다.
      await _storage.write(key: _explicitLogoutKey, value: '0');
      await _storage.write(key: _tokenKey, value: token);
    });
  }

  /// 저장된 액세스 토큰을 읽는다. 토큰 변경 작업이 진행 중이면 끝난 뒤의 값을 돌려준다.
  Future<String?> getToken() async {
    await _tokenMutation;
    return _storage.read(key: _tokenKey);
  }

  /// 저장된 토큰을 삭제하고 세션 세대를 올린다. 서버 호출 없이 로컬 상태만 정리한다.
  /// (서버 폐기까지 필요한 로그아웃은 [logoutSession] 사용)
  Future<void> clearToken() async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      await _storage.delete(key: _tokenKey);
    });
  }

  /// 로그에 남길 요청 본문에서 password, token, email이 포함된 키의 값을 가린다.
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

  /// 만료까지 [_refreshSkew] 이하로 남았거나, 만료 시각을 해석할 수 없으면 true.
  bool _isExpiringSoon(String token) {
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    if (expiresAt == null) return true;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(_refreshSkew));
  }

  /// 토큰이 없거나 이미 만료됐거나, 만료 시각을 해석할 수 없으면 true.
  bool _isExpired(String? token) {
    if (token == null) return true;
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    return expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc());
  }

  /// 오류 응답 본문(`message`, 없으면 `detail`)에서 화면에 보여줄 메시지를 꺼낸다.
  /// 문자열 값만 인정하며, 본문이 Map인데 쓸 수 있는 메시지가 없으면 일반 문구를,
  /// 본문이 Map이 아니면(네트워크 오류 등) null을 돌려준다.
  String? _responseMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['message', 'detail']) {
        final raw = data[key];
        if (raw is String) {
          final value = raw.trim();
          if (value.isNotEmpty) return value;
        }
      }
      return '요청 처리 중 오류가 발생했습니다.';
    }
    return null;
  }

  /// 토큰 저장소를 바꾸는 작업을 직렬화한다. 이전 작업이 끝난 뒤에 [action]을 실행하고,
  /// 실패하더라도 다음 작업이 막히지 않도록 반드시 락을 해제한다.
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

  /// 세션을 만료 처리한다. 이미 만료됐거나 [expectedGeneration]이 현재 세대와 다르면 아무것도 하지 않아
  /// 동시에 여러 요청이 401을 받아도 만료 콜백은 한 번만 호출된다.
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

  /// 명시적 로그아웃 상태로 전환한다. 세대를 올리고 토큰을 지우며 만료 콜백은 호출하지 않는다.
  Future<void> _markExplicitLogout() async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      _explicitlyLoggedOut = true;

      // 표식을 먼저 남겨 access token 삭제나 background revoke가 실패해도
      // 앱 재시작 시 HttpOnly refresh cookie로 자동 복구되지 않게 한다.
      await _storage.write(key: _explicitLogoutKey, value: '1');
      try {
        await _storage.delete(key: _tokenKey);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] explicit logout token delete failed: $e');
        }
      }
    });
  }
}
