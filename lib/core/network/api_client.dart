import 'dart:async';

import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:annual_leave_frontend/core/network/browser_credentials.dart';
import 'package:annual_leave_frontend/core/network/shared_sso_lock.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 세션 만료 시 현재 세대의 화면 전환을 요청한다
typedef UnauthorizedHandler = Future<void> Function(int generation);

// 인증 요청과 액세스 토큰 수명 주기를 관리한다
// 세션 세대와 토큰 변경 순서를 기준으로 이전 요청을 차단한다
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  // 액세스 토큰 저장 키를 관리한다
  static const _tokenKey = 'annual_leave_access_token';
  static const _explicitLogoutKey = 'annual_leave_explicit_logout';
  static const _sessionMarkerKey = 'annual_leave_sso_session_marker';
  static const _loggedOutSessionMarkerKey =
      'annual_leave_logged_out_sso_session_marker';
  static const _authGenerationKey = 'authGeneration';
  static const _intendedAuthGenerationKey = 'intendedAuthGeneration';

  // 인증 재시도 여부를 요청 정보에 기록한다
  static const _authRetriedKey = 'authRetried';

  // 만료 직전 토큰을 미리 갱신할 여유 시간을 둔다
  static const _refreshSkew = Duration(seconds: 45);

  // 모든 저장소가 같은 네트워크 클라이언트를 공유한다
  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  UnauthorizedHandler? _unauthorizedHandler;

  // 만료 처리 중 늦은 토큰 저장을 막는다
  bool _sessionExpired = false;
  bool _explicitlyLoggedOut = false;
  int _authGeneration = 0;
  int? _boundEmployeeId;
  String? _boundSessionMarker;
  bool _preserveReplacementSessionOnNextClear = false;
  Future<void> _tokenMutation = Future<void>.value();
  Future<LoginResponse?>? _refreshInFlight;

  // 인증 상태가 바뀔 때마다 세션 세대를 올린다
  int get sessionGeneration => _authGeneration;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    configureBrowserCredentials(dio);

    // 디버그 환경에서 민감 정보를 가린 요청 내용을 기록한다
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
      // 요청 직전에 현재 세션 토큰을 붙인다
      onRequest: (options, handler) async {
        await _attachCurrentAuthentication(options);
        return handler.next(options);
      },
      // 요청 후 세션이 바뀌었으면 이전 응답을 버린다
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
      // 인증 오류는 토큰 갱신 후 같은 요청을 다시 시도한다
      onError: (DioException error, handler) async {
        final requestGeneration =
            error.requestOptions.extra[_authGenerationKey] as int?;

        // 현재 세션의 첫 인증 실패만 재시도한다
        if (error.response?.statusCode == 401 &&
            requestGeneration != null &&
            requestGeneration == _authGeneration &&
            !_isAuthenticationRequest(error.requestOptions) &&
            error.requestOptions.extra[_authRetriedKey] != true) {
          try {
            final refreshed = await _refreshAccessTokenSingleFlight(
              requestGeneration,
              _bearerToken(error.requestOptions.headers['Authorization']),
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

  // 세션 만료 후 화면 전환 콜백을 등록한다
  void setUnauthorizedHandler(UnauthorizedHandler? handler) {
    _unauthorizedHandler = handler;
  }

  Future<T> runSharedSsoMutation<T>(Future<T> Function() action) {
    return withSharedSsoMutation(action);
  }

  // 인증 요청 생성 시점의 세대를 고정한다
  Future<Response<T>> authenticatedRequest<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    Dio? transport,
  }) {
    final intendedGeneration = _authGeneration;
    final original = options ?? Options();
    final stamped = original.copyWith(
      method: method,
      extra: {
        ...?original.extra,
        _intendedAuthGenerationKey: intendedGeneration,
      },
    );
    return (transport ?? dio).request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: stamped,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // 토큰 변경이 끝난 뒤 현재 세션의 인증 정보를 요청에 붙인다
  Future<void> _attachCurrentAuthentication(RequestOptions options) async {
    if (_isAuthenticationRequest(options)) {
      options.headers.remove('Authorization');
      options.extra.remove(_authGenerationKey);
      options.extra.remove(_intendedAuthGenerationKey);
      return;
    }

    // 인증 부착을 시작한 세대를 고정해 계정 전환을 감지한다
    final intendedGeneration =
        options.extra[_intendedAuthGenerationKey] as int? ?? _authGeneration;
    options.extra[_intendedAuthGenerationKey] = intendedGeneration;

    while (true) {
      _requireSameSession(options, intendedGeneration);
      final barrier = _tokenMutation;
      await barrier;
      _requireSameSession(options, intendedGeneration);

      if (_isAuthenticationRequest(options)) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
        return;
      }

      if (_explicitlyLoggedOut) {
        _requireSameSession(options, intendedGeneration);
      }

      var token = await _storage.read(key: _tokenKey);
      _requireSameSession(options, intendedGeneration);
      if (barrier != _tokenMutation) continue;

      final storedEmployeeId = token == null
          ? null
          : LoginResponse.tryFromAccessToken(token)?.employeeId;
      final boundEmployeeId = _boundEmployeeId;
      if (boundEmployeeId != null &&
          storedEmployeeId != null &&
          storedEmployeeId != boundEmployeeId) {
        // 다른 탭의 계정으로 바뀌면 현재 화면 세션만 만료한다
        await _expireLocalSessionOnly(intendedGeneration);
        _requireSameSession(options, intendedGeneration);
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
        return;
      }

      // 복원 중인 화면 세션을 현재 토큰 사용자에 연결한다
      _boundEmployeeId ??= storedEmployeeId;

      // 만료가 가까운 토큰은 요청 전에 갱신한다
      if (token != null && _isExpiringSoon(token)) {
        try {
          final refreshed =
              await _refreshAccessTokenSingleFlight(intendedGeneration, token);
          if (refreshed != null) {
            token = refreshed.token;
          } else {
            token = await _storage.read(key: _tokenKey);
          }
          _requireSameSession(options, intendedGeneration);
        } on DioException {
          // 일시 장애면 유효한 기존 토큰으로 계속 진행한다
          if (_isExpired(token)) rethrow;
        }
      }

      _requireSameSession(options, intendedGeneration);

      if (token == null) {
        options.headers.remove('Authorization');
        options.extra.remove(_authGenerationKey);
      } else {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_authGenerationKey] = intendedGeneration;
      }
      return;
    }
  }

  void _requireSameSession(
    RequestOptions options,
    int intendedGeneration,
  ) {
    if (_explicitlyLoggedOut || intendedGeneration != _authGeneration) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        message: '계정이 변경되어 이전 요청을 취소했습니다.',
      );
    }
  }

  // 인증 API는 액세스 토큰과 자동 재시도를 사용하지 않는다
  bool _isAuthenticationRequest(RequestOptions options) {
    return options.path.startsWith('/api/auth/');
  }

  String? _bearerToken(Object? authorization) {
    if (authorization is! String) return null;
    const prefix = 'Bearer ';
    return authorization.startsWith(prefix)
        ? authorization.substring(prefix.length)
        : null;
  }

  // 동시에 들어온 토큰 갱신 요청은 하나의 결과를 공유한다
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

  // 토큰 갱신 충돌을 확인한 뒤 새 토큰을 저장한다
  Future<LoginResponse?> _performRefresh(
    int expectedGeneration,
    String? beforeToken,
  ) {
    return runSharedSsoMutation(
      () => _performRefreshLocked(expectedGeneration, beforeToken),
    );
  }

  Future<LoginResponse?> _performRefreshLocked(
    int expectedGeneration,
    String? beforeToken,
  ) async {
    final expectedSessionMarker =
        await _resolveRefreshSessionMarker(expectedGeneration);
    if (expectedSessionMarker == null ||
        expectedGeneration != _authGeneration) {
      return null;
    }

    Options refreshOptions() => Options(headers: {
          'X-SSO-Refresh': '1',
          'X-SSO-Session-Marker': expectedSessionMarker,
        });

    Response<dynamic> response;
    try {
      response = await dio.post(
        '/api/auth/refresh',
        options: refreshOptions(),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        // 다른 로그인 세션으로 쿠키가 바뀌면 현재 화면 세션만 만료한다
        try {
          final currentCookieMarker = await _fetchCurrentSessionMarker();
          if (currentCookieMarker == null ||
              currentCookieMarker != expectedSessionMarker) {
            await _expireLocalSessionOnly(expectedGeneration);
            return null;
          }
        } on DioException catch (probeError) {
          return _handleRefreshFailure(
            probeError,
            expectedGeneration,
            expectedSessionMarker: expectedSessionMarker,
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // 다른 탭이 갱신한 토큰이 있으면 그대로 사용한다
        final sharedToken = await _storage.read(key: _tokenKey);
        if (sharedToken != null &&
            sharedToken != beforeToken &&
            !_isExpired(sharedToken)) {
          final sharedSession = LoginResponse.tryFromAccessToken(sharedToken);
          if (!_sameSubject(beforeToken, sharedSession)) {
            await _expireLocalSessionOnly(expectedGeneration);
            return null;
          }
          return sharedSession;
        }

        try {
          response = await dio.post(
            '/api/auth/refresh',
            options: refreshOptions(),
          );
        } on DioException catch (retryError) {
          return _handleRefreshFailure(
            retryError,
            expectedGeneration,
            expectedSessionMarker: expectedSessionMarker,
          );
        }
      } else {
        return _handleRefreshFailure(
          error,
          expectedGeneration,
          expectedSessionMarker: expectedSessionMarker,
        );
      }
    }

    final refreshed =
        LoginResponse.fromJson(Map<String, dynamic>.from(response.data as Map));

    // 갱신 결과의 사용자가 달라지면 현재 세션을 종료한다
    if (!_sameSubject(beforeToken, refreshed)) {
      await _expireLocalSessionOnly(expectedGeneration);
      return null;
    }

    final replaced = await _replaceAccessToken(
      refreshed.token,
      expectedGeneration,
      sessionMarker: refreshed.ssoSessionMarker,
    );
    if (!replaced) return null;
    return refreshed;
  }

  Future<String?> _resolveRefreshSessionMarker(
    int expectedGeneration,
  ) async {
    final stored = await _storage.read(key: _sessionMarkerKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    try {
      final discovered = await _fetchCurrentSessionMarker();
      if (discovered == null || discovered.isEmpty) {
        return null;
      }

      var saved = false;
      await _mutateToken(() async {
        if (expectedGeneration != _authGeneration || _sessionExpired) return;
        await _storage.write(key: _sessionMarkerKey, value: discovered);
        _boundSessionMarker = discovered;
        saved = true;
      });
      return saved ? discovered : null;
    } on DioException catch (error) {
      return _handleMarkerDiscoveryFailure(error, expectedGeneration);
    }
  }

  Future<String?> _handleMarkerDiscoveryFailure(
    DioException error,
    int expectedGeneration,
  ) async {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      await _expireRefreshFailureSession(expectedGeneration);
      return null;
    }
    throw error;
  }

  Future<String?> _fetchCurrentSessionMarker() async {
    final response = await dio.post(
      '/api/auth/session-marker',
      options: Options(headers: const {'X-SSO-Refresh': '1'}),
    );
    final data = response.data;
    if (data is! Map) return null;
    final marker = data['sessionMarker']?.toString();
    return marker == null || marker.isEmpty ? null : marker;
  }

  bool _sameSubject(String? beforeToken, LoginResponse? candidate) {
    if (beforeToken == null || candidate == null) return true;

    final before = LoginResponse.tryFromAccessToken(beforeToken);
    final beforeEmployeeId = before?.employeeId;
    final candidateEmployeeId = candidate.employeeId;
    if (beforeEmployeeId == null || candidateEmployeeId == null) return true;

    return beforeEmployeeId == candidateEmployeeId;
  }

  // 갱신 실패 원인에 따라 세션 만료와 일시 장애를 구분한다
  Future<LoginResponse?> _handleRefreshFailure(
    DioException error,
    int expectedGeneration, {
    String? expectedSessionMarker,
  }) async {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      await _expireRefreshFailureSession(
        expectedGeneration,
        expectedSessionMarker: expectedSessionMarker,
      );
      return null;
    }
    throw error;
  }

  // 현재 세션이 유지될 때만 갱신된 토큰을 저장한다
  Future<bool> _replaceAccessToken(
    String token,
    int expectedGeneration, {
    String? sessionMarker,
  }) async {
    var replaced = false;
    await _mutateToken(() async {
      if (expectedGeneration != _authGeneration || _sessionExpired) return;
      await _storage.write(key: _tokenKey, value: token);
      _boundEmployeeId = LoginResponse.tryFromAccessToken(token)?.employeeId;
      _preserveReplacementSessionOnNextClear = false;
      if (sessionMarker == null || sessionMarker.isEmpty) {
        _boundSessionMarker = null;
        await _storage.delete(key: _sessionMarkerKey);
      } else {
        _boundSessionMarker = sessionMarker;
        await _storage.write(key: _sessionMarkerKey, value: sessionMarker);
      }
      replaced = true;
    });
    return replaced;
  }

  // 앱 시작 시 저장된 토큰이나 갱신 세션으로 로그인을 복원한다
  Future<LoginResponse?> restoreSession() async {
    await _tokenMutation;
    var generation = _authGeneration;
    final explicitLogout = await _storage.read(key: _explicitLogoutKey);
    if (explicitLogout != null && explicitLogout != '0') {
      _explicitlyLoggedOut = true;
      final replacementActivated =
          await _activateReplacementSsoSession(generation, explicitLogout);
      if (!replacementActivated) {
        return null;
      }
      generation = _authGeneration;
    }

    _explicitlyLoggedOut = false;
    final token = await _storage.read(key: _tokenKey);
    if (token != null && !_isExpiringSoon(token)) {
      final restored = LoginResponse.tryFromAccessToken(token);
      _boundEmployeeId = restored?.employeeId;
      _boundSessionMarker = await _storage.read(key: _sessionMarkerKey);
      return restored;
    }

    try {
      return await _refreshAccessTokenSingleFlight(generation, token);
    } on DioException {
      if (token != null && !_isExpired(token)) {
        final restored = LoginResponse.tryFromAccessToken(token);
        _boundEmployeeId = restored?.employeeId;
        _boundSessionMarker = await _storage.read(key: _sessionMarkerKey);
        return restored;
      }
      rethrow;
    }
  }

  Future<bool> _activateReplacementSsoSession(
    int expectedGeneration,
    String explicitLogoutValue,
  ) async {
    final embeddedMarker = explicitLogoutValue.startsWith('session:')
        ? explicitLogoutValue.substring('session:'.length)
        : null;
    final loggedOutMarker = embeddedMarker != null && embeddedMarker.isNotEmpty
        ? embeddedMarker
        : await _storage.read(key: _loggedOutSessionMarkerKey);
    if (loggedOutMarker == null || loggedOutMarker.isEmpty) {
      return false;
    }

    String? currentMarker;
    try {
      final response = await dio.post(
        '/api/auth/session-marker',
        options: Options(headers: const {'X-SSO-Refresh': '1'}),
      );
      final data = response.data;
      if (data is Map) {
        currentMarker = data['sessionMarker']?.toString();
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return false;
      }
      // 명시 로그아웃 상태에서는 일시적인 probe 장애를 로그인 복구로 오인하지 않는다.
      return false;
    }

    if (currentMarker == null ||
        currentMarker.isEmpty ||
        currentMarker == loggedOutMarker) {
      return false;
    }

    var activated = false;
    await _mutateToken(() async {
      if (expectedGeneration != _authGeneration) return;

      _authGeneration++;
      _sessionExpired = false;
      _explicitlyLoggedOut = false;
      _preserveReplacementSessionOnNextClear = false;
      await _storage.write(key: _explicitLogoutKey, value: '0');
      await _storage.write(key: _sessionMarkerKey, value: currentMarker);
      _boundSessionMarker = currentMarker;
      await _storage.delete(key: _loggedOutSessionMarkerKey);
      activated = true;
    });
    return activated;
  }

  // 서버 세션 정리를 시도한 뒤 로컬 로그아웃을 완료한다
  Future<void> logoutSession({String? fcmToken}) async {
    // shared SSO mutation lock 안에서 현재 탭이 소유한 marker와 shared marker를 먼저 비교한다.
    // 다른 탭이 이미 새 세션으로 교체했다면 그 세션의 token/fence/cookie는 건드리지 않는다.
    final logout = await _prepareExplicitLogout();
    if (logout.replacementDetected) return;

    final sessionMarker = logout.sessionMarker;
    if (sessionMarker != null && sessionMarker.isNotEmpty) {
      if (logout.fencePersisted) {
        // 로그아웃 상태를 먼저 저장하고 서버 세션 정리를 시도한다
        await _revokeLoggedOutSession(
          fcmToken: fcmToken,
          sessionMarker: sessionMarker,
          swallowFailure: false,
        );
      }
      return;
    }

    if (!logout.fencePersisted) {
      throw StateError('로그아웃 상태를 저장하거나 서버 세션을 식별할 수 없습니다.');
    }
  }

  // 로그인 확정 실패 시 생성된 서버 세션을 정리한다
  Future<void> discardRefreshSession(
    String sessionMarker, {
    bool clearLocalState = true,
  }) async {
    if (sessionMarker.isEmpty) return;

    if (!clearLocalState) {
      // 새 세션이 활성화됐으면 이전 서버 세션만 정리한다
      await _revokeLoggedOutSession(
        sessionMarker: sessionMarker,
        swallowFailure: true,
      );
      return;
    }

    final discard = await _prepareExplicitLogout(
      sessionMarkerOverride: sessionMarker,
    );
    // replacement session이 이미 shared storage/cookie를 차지했다면 로컬 저장소는
    // 보존하고, 옛 marker에 대한 backend revoke만 marker-bound로 시도한다.
    await _revokeLoggedOutSession(
      sessionMarker: sessionMarker,
      swallowFailure:
          discard.replacementDetected || discard.fencePersisted,
    );
  }

  Future<void> _revokeLoggedOutSession({
    String? fcmToken,
    required String sessionMarker,
    bool swallowFailure = true,
  }) async {
    try {
      await runSharedSsoMutation(() {
        return dio.post(
          '/api/auth/logout',
          data: fcmToken == null ? null : {'fcmToken': fcmToken},
          options: Options(
            headers: {
              'X-SSO-Refresh': '1',
              'X-SSO-Background-Logout': '1',
              'X-SSO-Session-Marker': sessionMarker,
            },
          ),
        );
      });
    } on DioException {
      if (!swallowFailure) rethrow;
      // 로그아웃 상태가 저장되면 서버 장애가 있어도 자동 복구하지 않는다
    }
  }

  // 로그인 성공 후 새 토큰을 저장하고 세션 세대를 갱신한다
  Future<void> saveToken(
    String token, {
    String? sessionMarker,
  }) async {
    await _mutateToken(() async {
      _authGeneration++;
      _sessionExpired = false;
      _explicitlyLoggedOut = false;
      _preserveReplacementSessionOnNextClear = false;
      await _storage.write(key: _explicitLogoutKey, value: '0');
      await _storage.delete(key: _loggedOutSessionMarkerKey);
      await _storage.write(key: _tokenKey, value: token);
      _boundEmployeeId = LoginResponse.tryFromAccessToken(token)?.employeeId;
      if (sessionMarker == null || sessionMarker.isEmpty) {
        _boundSessionMarker = null;
        await _storage.delete(key: _sessionMarkerKey);
      } else {
        _boundSessionMarker = sessionMarker;
        await _storage.write(key: _sessionMarkerKey, value: sessionMarker);
      }
    });
  }

  // 토큰 변경 작업이 끝난 뒤 저장된 토큰을 읽는다
  Future<String?> getToken() async {
    await _tokenMutation;
    return _storage.read(key: _tokenKey);
  }

  // 현재 갱신 세션 식별자를 저장소나 쿠키에서 확인한다
  Future<String?> getSessionMarker() async {
    await _tokenMutation;
    final generation = _authGeneration;
    final stored = await _storage.read(key: _sessionMarkerKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return _resolveRefreshSessionMarker(generation);
  }

  // 로컬 토큰을 삭제하고 세션 세대를 갱신한다
  Future<void> clearToken() {
    return runSharedSsoMutation(() async {
      await _mutateToken(() async {
        final sharedToken = await _storage.read(key: _tokenKey);
        final sharedMarker = await _storage.read(key: _sessionMarkerKey);
        final sharedEmployeeId = sharedToken == null
            ? null
            : LoginResponse.tryFromAccessToken(sharedToken)?.employeeId;

        final subjectReplaced = _boundEmployeeId != null &&
            sharedEmployeeId != null &&
            sharedEmployeeId != _boundEmployeeId;
        final markerReplaced = _boundSessionMarker != null &&
            _boundSessionMarker!.isNotEmpty &&
            sharedMarker != null &&
            sharedMarker.isNotEmpty &&
            sharedMarker != _boundSessionMarker;
        final replacementSession = _preserveReplacementSessionOnNextClear ||
            subjectReplaced ||
            markerReplaced;

        _authGeneration++;
        _sessionExpired = false;
        _boundEmployeeId = null;
        _boundSessionMarker = null;
        _preserveReplacementSessionOnNextClear = false;

        if (!replacementSession) {
          await _storage.delete(key: _tokenKey);
          await _storage.delete(key: _sessionMarkerKey);
        }
      });
    });
  }

  // 로그에 남길 민감한 요청 값을 가린다
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

  // 토큰이 갱신 시점에 가까운지 확인한다
  bool _isExpiringSoon(String token) {
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    if (expiresAt == null) return true;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(_refreshSkew));
  }

  // 토큰의 현재 만료 여부를 확인한다
  bool _isExpired(String? token) {
    if (token == null) return true;
    final expiresAt =
        LoginResponse.tryFromAccessToken(token)?.accessTokenExpiresAt;
    return expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc());
  }

  // 서버 오류 응답에서 화면에 보여줄 메시지를 찾는다
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

  // 토큰 저장소 변경 작업을 순서대로 실행한다
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

  // 세션 만료 전 현재 탭의 토큰 소유권을 다시 확인한다
  Future<void> _expireRefreshFailureSession(
    int expectedGeneration, {
    String? expectedSessionMarker,
  }) async {
    int? expiredGeneration;
    await _mutateToken(() async {
      if (_sessionExpired || expectedGeneration != _authGeneration) return;

      final storedToken = await _storage.read(key: _tokenKey);
      final storedMarker = await _storage.read(key: _sessionMarkerKey);
      final storedEmployeeId = storedToken == null
          ? null
          : LoginResponse.tryFromAccessToken(storedToken)?.employeeId;

      final subjectReplaced = _boundEmployeeId != null &&
          storedEmployeeId != null &&
          storedEmployeeId != _boundEmployeeId;
      final markerReplaced = expectedSessionMarker != null &&
          storedMarker != null &&
          storedMarker != expectedSessionMarker;
      final replacementSession = subjectReplaced || markerReplaced;

      _sessionExpired = true;
      _preserveReplacementSessionOnNextClear = replacementSession;
      _boundEmployeeId = null;
      _boundSessionMarker = null;
      expiredGeneration = ++_authGeneration;

      if (!replacementSession) {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _sessionMarkerKey);
      }
    });

    final generation = expiredGeneration;
    if (generation != null && generation == _authGeneration) {
      await _unauthorizedHandler?.call(generation);
    }
  }

  // 다른 탭의 로그인 사용자가 바뀌면 현재 화면 세션만 만료한다
  Future<void> _expireLocalSessionOnly(int expectedGeneration) async {
    int? expiredGeneration;
    await _mutateToken(() async {
      if (_sessionExpired || expectedGeneration != _authGeneration) return;
      _sessionExpired = true;
      _preserveReplacementSessionOnNextClear = true;
      _boundEmployeeId = null;
      _boundSessionMarker = null;
      expiredGeneration = ++_authGeneration;
    });

    final generation = expiredGeneration;
    if (generation != null && generation == _authGeneration) {
      await _unauthorizedHandler?.call(generation);
    }
  }

  Future<({
    String? sessionMarker,
    bool fencePersisted,
    bool replacementDetected,
  })> _prepareExplicitLogout({String? sessionMarkerOverride}) {
    return runSharedSsoMutation(() async {
      final tabOwnedMarker = _boundSessionMarker;
      final ownedMarker = sessionMarkerOverride ?? tabOwnedMarker;
      final sharedMarker = await _storage.read(key: _sessionMarkerKey);
      final sharedToken = await _storage.read(key: _tokenKey);
      final sharedEmployeeId = sharedToken == null
          ? null
          : LoginResponse.tryFromAccessToken(sharedToken)?.employeeId;

      final subjectReplaced = _boundEmployeeId != null &&
          sharedEmployeeId != null &&
          sharedEmployeeId != _boundEmployeeId;
      final markerReplaced = ownedMarker != null &&
          ownedMarker.isNotEmpty &&
          sharedMarker != null &&
          sharedMarker.isNotEmpty &&
          sharedMarker != ownedMarker &&
          // 현재 탭이 소유한 세션 식별자로 교체 여부를 판단한다
          tabOwnedMarker != null &&
          tabOwnedMarker.isNotEmpty &&
          sharedMarker != tabOwnedMarker;

      if (subjectReplaced || markerReplaced) {
        // 현재 탭 상태만 닫고 다른 탭의 세션 정보는 보존한다
        await _mutateToken(() async {
          _authGeneration++;
          _sessionExpired = false;
          _explicitlyLoggedOut = true;
          _boundEmployeeId = null;
          _boundSessionMarker = null;
          _preserveReplacementSessionOnNextClear = true;
        });
        return (
          sessionMarker: ownedMarker,
          fencePersisted: false,
          replacementDetected: true,
        );
      }

      final marked = await _markExplicitLogout(
        sessionMarkerOverride: ownedMarker,
      );
      return (
        sessionMarker: marked.sessionMarker,
        fencePersisted: marked.fencePersisted,
        replacementDetected: false,
      );
    });
  }

  // 현재 세션을 로컬 종료 상태로 바꾸고 서버 정리를 준비한다
  Future<({String? sessionMarker, bool fencePersisted})>
      _markExplicitLogout({String? sessionMarkerOverride}) async {
    String? sessionMarker;
    var fencePersisted = false;
    await _mutateToken(() async {
      sessionMarker = sessionMarkerOverride ??
          await _storage.read(key: _sessionMarkerKey);
      _authGeneration++;
      _sessionExpired = false;
      _boundEmployeeId = null;
      _boundSessionMarker = null;
      _explicitlyLoggedOut = true;
      _preserveReplacementSessionOnNextClear = false;

      // 일부 정리가 실패해도 남은 세션 정리를 계속한다
      try {
        final fenceValue = sessionMarker != null && sessionMarker!.isNotEmpty
            ? 'session:$sessionMarker'
            : '1';
        await _storage.write(key: _explicitLogoutKey, value: fenceValue);
        fencePersisted = true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] explicit logout marker write failed: $e');
        }
      }
      try {
        await _storage.delete(key: _tokenKey);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] explicit logout token delete failed: $e');
        }
      }
      try {
        await _storage.delete(key: _sessionMarkerKey);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] session marker delete failed: $e');
        }
      }
    });
    return (
      sessionMarker: sessionMarker,
      fencePersisted: fencePersisted,
    );
  }
}


// 저장소 요청에 현재 인증 세대를 고정하는 보호 호출을 제공한다
extension AuthenticatedDioRequests on Dio {
  Future<Response<T>> authenticatedGet<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      ApiClient().authenticatedRequest<T>(
        path,
        method: 'GET',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        transport: this,
      );

  Future<Response<T>> authenticatedPost<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      ApiClient().authenticatedRequest<T>(
        path,
        method: 'POST',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        transport: this,
      );

  Future<Response<T>> authenticatedPut<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      ApiClient().authenticatedRequest<T>(
        path,
        method: 'PUT',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        transport: this,
      );

  Future<Response<T>> authenticatedPatch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      ApiClient().authenticatedRequest<T>(
        path,
        method: 'PATCH',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        transport: this,
      );

  Future<Response<T>> authenticatedDelete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      ApiClient().authenticatedRequest<T>(
        path,
        method: 'DELETE',
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        transport: this,
      );
}
