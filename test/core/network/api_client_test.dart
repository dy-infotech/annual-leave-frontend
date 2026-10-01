import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const _validAccessToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI3IiwibmFtZSI6Iu2Zjeq4uOuPmSIsInJvbGUiOiJBRE1JTiIsImV4cCI6NDEwMjQ0NDgwMH0.signature';
const _otherAccessToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI4IiwibmFtZSI6Ik90aGVyIiwicm9sZSI6IkVNUExPWUVFIiwiZXhwIjo0MTAyNDQ0ODAwfQ.signature';

/// ApiClient 특성화 테스트.
///
/// 전 화면이 보여주는 에러 메시지가 이 클래스의 onError 인터셉터에서 만들어지므로
/// 현재 동작을 그대로 기록한다. JWT 저장소는 플랫폼 채널을 타므로
/// 채널 핸들러를 메모리 저장소처럼 동작시켜 토큰이 있는 경우까지 확인한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late DioAdapter dioAdapter;
  late List<MethodCall> storageCalls;
  String? storedToken;
  String? explicitLogoutMarker;
  String? sessionMarker;

  setUp(() {
    storageCalls = <MethodCall>[];
    storedToken = null;
    explicitLogoutMarker = null;
    sessionMarker = 'session-a';
    ApiClient().setUnauthorizedHandler(null);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      storageCalls.add(call);
      final args = call.arguments as Map?;
      final key = args?['key'] as String?;
      final explicitKey = key == 'annual_leave_explicit_logout';
      final sessionKey = key == 'annual_leave_sso_session_marker';
      switch (call.method) {
        case 'read':
          if (explicitKey) return explicitLogoutMarker;
          if (sessionKey) return sessionMarker;
          return storedToken;
        case 'write':
          if (explicitKey) {
            explicitLogoutMarker = args?['value'] as String?;
          } else if (sessionKey) {
            sessionMarker = args?['value'] as String?;
          } else {
            storedToken = args?['value'] as String?;
          }
          return null;
        case 'delete':
          if (explicitKey) {
            explicitLogoutMarker = null;
          } else if (sessionKey) {
            sessionMarker = null;
          } else {
            storedToken = null;
          }
          return null;
      }
      return null;
    });

    // ApiClient는 싱글턴이라 dio 인스턴스가 테스트 간 공유된다.
    // DioAdapter 생성자가 httpClientAdapter를 교체하므로 테스트마다 새로 붙인다.
    dioAdapter = DioAdapter(dio: ApiClient().dio);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('인스턴스', () {
    test('ApiClient()는 언제나 같은 인스턴스를 돌려준다', () {
      expect(identical(ApiClient(), ApiClient()), isTrue);
      expect(identical(ApiClient().dio, ApiClient().dio), isTrue);
    });

    test('dio 기본 옵션에 baseUrl과 10초 타임아웃이 설정된다', () {
      final options = ApiClient().dio.options;

      expect(options.baseUrl, ApiConfig.baseUrl);
      expect(options.connectTimeout, const Duration(seconds: 10));
      expect(options.receiveTimeout, const Duration(seconds: 10));
    });
  });

  group('JWT 인터셉터', () {
    test('저장된 토큰이 있으면 Authorization 헤더를 붙인다', () async {
      storedToken = _validAccessToken;
      dioAdapter.onGet('/api/employees/me', (server) => server.reply(200, {}));

      final response = await ApiClient().dio.get('/api/employees/me');

      expect(
        response.requestOptions.headers['Authorization'],
        'Bearer $_validAccessToken',
      );
      expect(storageCalls.map((call) => call.method), contains('read'));
      expect(
        (storageCalls.first.arguments as Map)['key'],
        'annual_leave_access_token',
      );
    });

    test('저장된 토큰이 없으면 Authorization 헤더를 붙이지 않는다', () async {
      dioAdapter.onGet('/api/employees/me', (server) => server.reply(200, {}));

      final response = await ApiClient().dio.get('/api/employees/me');

      expect(response.requestOptions.headers.containsKey('Authorization'),
          isFalse);
    });
  });

  group('onError 인터셉터 - 에러 메시지 변환', () {
    test('응답 본문이 Map이고 message가 있으면 그 메시지를 쓴다', () async {
      dioAdapter.onPost(
        '/api/leave-requests',
        (server) => server.reply(400, {'message': '이미 신청한 날짜입니다.'}),
        data: {'leaveType': 'FULL'},
      );

      final error = await _captureDioException(
        () => ApiClient().dio.post(
              '/api/leave-requests',
              data: {'leaveType': 'FULL'},
            ),
      );

      expect(error.message, '이미 신청한 날짜입니다.');
      expect(error.response?.statusCode, 400);
    });

    test('응답 본문이 Map인데 message가 없으면 알 수 없는 오류 메시지를 쓴다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(400, {'error': 'BAD_REQUEST'}),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.message, '요청 처리 중 오류가 발생했습니다.');
    });

    test('응답 본문이 Map이 아니면 네트워크 오류 메시지를 쓴다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(500, 'Internal Server Error'),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.message, '네트워크 오류가 발생했습니다.');
    });

    test('응답 본문이 배열이어도 네트워크 오류 메시지를 쓴다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(500, ['오류1', '오류2']),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.message, '네트워크 오류가 발생했습니다.');
    });

    test('응답 자체가 없는 연결 오류도 네트워크 오류 메시지가 된다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.throws(
          500,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/api/employees/me'),
            reason: '서버에 연결할 수 없습니다',
          ),
        ),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response, isNull);
      expect(error.message, '네트워크 오류가 발생했습니다.');
    });

    test('message 값이 문자열이 아니어도 원래 응답을 보존한다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(400, {
          'message': {'employeeNumber': '필수 값입니다'}
        }),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.type, DioExceptionType.badResponse);
      expect(error.response?.statusCode, 400);
      expect(error.response?.data, isA<Map>());
      expect(error.message, '요청 처리 중 오류가 발생했습니다.');
    });
  });

  group('401 응답', () {
    test('인증된 요청의 401은 토큰을 지우고 세션 만료 핸들러를 호출한다', () async {
      storedToken = _validAccessToken;
      var expiredCount = 0;
      ApiClient().setUnauthorizedHandler((_) async {
        expiredCount++;
      });
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': '인증 정보가 유효하지 않습니다.'}),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) => server.reply(401, {'message': 'refresh session이 만료되었습니다.'}),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(error.message, '인증 정보가 유효하지 않습니다.');
      expect(storedToken, isNull);
      expect(storageCalls.map((call) => call.method), contains('delete'));
      expect(expiredCount, 1);
    });

    test('refresh 응답의 사용자가 현재 access token과 다르면 세션을 만료한다', () async {
      await ApiClient().saveToken(_validAccessToken);
      var expiredCount = 0;
      ApiClient().setUnauthorizedHandler((_) async {
        expiredCount++;
      });
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': 'access token 만료'}),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) => server.reply(200, {
          'token': _otherAccessToken,
          'employeeId': 8,
          'name': 'Other',
          'role': 'EMPLOYEE',
        }),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(storedToken, isNull);
      expect(expiredCount, 1);
    });

    test('refresh 409 뒤 cookie session marker가 다르면 로컬 세션만 만료한다', () async {
      storedToken = _validAccessToken;
      sessionMarker = 'session-a';
      var expiredCount = 0;
      var refreshCalls = 0;
      ApiClient().setUnauthorizedHandler((_) async {
        expiredCount++;
      });

      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': 'access token 만료'}),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) {
          refreshCalls++;
          server.reply(409, {'message': 'session marker mismatch'});
        },
      );
      dioAdapter.onPost(
        '/api/auth/session-marker',
        (server) => server.reply(200, {'sessionMarker': 'session-b'}),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(refreshCalls, 1);
      expect(storedToken, isNull);
      expect(expiredCount, 1);
    });

    test('marker가 없는 기존 세션은 cookie marker를 조회한 뒤 refresh한다', () async {
      storedToken = _validAccessToken;
      sessionMarker = null;
      var refreshMarker = '';
      final captureRefreshHeader = InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/api/auth/refresh') {
            refreshMarker =
                options.headers['X-SSO-Session-Marker']?.toString() ?? '';
          }
          handler.next(options);
        },
      );
      ApiClient().dio.interceptors.add(captureRefreshHeader);

      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': 'access token 만료'}),
      );
      dioAdapter.onPost(
        '/api/auth/session-marker',
        (server) => server.reply(200, {'sessionMarker': 'bootstrapped'}),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) {
          server.reply(200, {
            'token': _validAccessToken,
            'employeeId': 7,
            'name': '홍길동',
            'role': 'ADMIN',
            'ssoSessionMarker': 'bootstrapped',
          });
        },
      );
      // 재시도되는 원 GET도 성공시킨다.
      var getCount = 0;
      dioAdapter.onGet(
        '/api/employees/me',
        (server) {
          getCount++;
          if (getCount == 1) {
            server.reply(401, {'message': 'access token 만료'});
          } else {
            server.reply(200, {});
          }
        },
      );

      try {
        final response = await ApiClient().dio.get('/api/employees/me');

        expect(response.statusCode, 200);
        expect(refreshMarker, 'bootstrapped');
        expect(sessionMarker, 'bootstrapped');
      } finally {
        ApiClient().dio.interceptors.remove(captureRefreshHeader);
      }
    });

    test('공개 로그인 요청의 401은 기존 세션 만료로 처리하지 않는다', () async {
      storedToken = 'existing.token';
      var expiredCount = 0;
      ApiClient().setUnauthorizedHandler((_) async {
        expiredCount++;
      });
      dioAdapter.onPost(
        '/api/auth/signin',
        (server) => server.reply(401, {'message': '사번 또는 비밀번호가 일치하지 않습니다.'}),
        data: {'employeeNumber': 'A0001', 'password': 'wrong'},
      );

      final error = await _captureDioException(
        () => ApiClient().dio.post(
              '/api/auth/signin',
              data: {'employeeNumber': 'A0001', 'password': 'wrong'},
            ),
      );

      expect(error.response?.statusCode, 401);
      expect(error.requestOptions.headers.containsKey('Authorization'), isFalse);
      expect(storedToken, 'existing.token');
      expect(expiredCount, 0);
    });

    test('401 응답 본문이 비어 있으면 네트워크 오류 메시지가 된다', () async {
      storedToken = _validAccessToken;
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, null),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) => server.reply(401, null),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(error.message, '네트워크 오류가 발생했습니다.');
    });
  });

  group('명시 로그아웃 SSO 복구', () {
    test('로그아웃 뒤 다른 앱이 만든 새 shared SSO session을 다시 발견한다', () async {
      await ApiClient().saveToken(
        _validAccessToken,
        sessionMarker: 'session-a',
      );

      dioAdapter.onPost(
        '/api/auth/logout',
        (server) => server.reply(204, null),
      );

      await ApiClient().logoutSession();

      expect(explicitLogoutMarker, 'session:session-a');
      expect(storedToken, isNull);
      expect(sessionMarker, isNull);

      // 다른 시스템(resource-management)이 같은 origin의 shared refresh
      // cookie를 새 session-b로 교체한 상황을 backend probe/refresh로 모사한다.
      dioAdapter.onPost(
        '/api/auth/session-marker',
        (server) => server.reply(200, {'sessionMarker': 'session-b'}),
      );
      dioAdapter.onPost(
        '/api/auth/refresh',
        (server) => server.reply(200, {
          'token': _validAccessToken,
          'employeeId': 7,
          'name': '홍길동',
          'role': 'ADMIN',
          'ssoSessionMarker': 'session-b',
        }),
      );

      final restored = await ApiClient().restoreSession();

      expect(restored, isNotNull);
      expect(restored!.employeeId, 7);
      expect(explicitLogoutMarker, '0');
      expect(sessionMarker, 'session-b');
      expect(storedToken, _validAccessToken);
    });
  });

  group('토큰 저장소', () {
    test('saveToken은 annual_leave_access_token 키로 값을 저장한다', () async {
      await ApiClient().saveToken('new.jwt.token');

      final write = storageCalls.firstWhere((call) {
        final args = call.arguments as Map?;
        return call.method == 'write' &&
            args?['key'] == 'annual_leave_access_token';
      });
      expect((write.arguments as Map)['key'], 'annual_leave_access_token');
      expect((write.arguments as Map)['value'], 'new.jwt.token');
      expect(storedToken, 'new.jwt.token');
    });

    test('getToken은 저장된 값을 돌려주고, 없으면 null을 돌려준다', () async {
      expect(await ApiClient().getToken(), isNull);

      storedToken = 'saved.jwt.token';
      expect(await ApiClient().getToken(), 'saved.jwt.token');
    });

    test('clearToken은 annual_leave_access_token 키를 삭제한다', () async {
      storedToken = 'saved.jwt.token';

      await ApiClient().clearToken();

      final delete = storageCalls.firstWhere((call) => call.method == 'delete');
      expect((delete.arguments as Map)['key'], 'annual_leave_access_token');
      expect(storedToken, isNull);
    });

    test('saveToken 후 getToken으로 같은 값을 다시 읽을 수 있다', () async {
      await ApiClient().saveToken('round.trip.token');

      expect(await ApiClient().getToken(), 'round.trip.token');
    });
  });
}

/// 요청이 던진 DioException을 잡아서 돌려준다.
Future<DioException> _captureDioException(
    Future<Response<dynamic>> Function() request) async {
  try {
    await request();
  } on DioException catch (error) {
    return error;
  }
  fail('DioException이 발생하지 않았다');
}
