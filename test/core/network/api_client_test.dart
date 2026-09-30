import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

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

  setUp(() {
    storageCalls = <MethodCall>[];
    storedToken = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      storageCalls.add(call);
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'read':
          return storedToken;
        case 'write':
          storedToken = args?['value'] as String?;
          return null;
        case 'delete':
          storedToken = null;
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
      storedToken = 'header.payload.signature';
      dioAdapter.onGet('/api/employees/me', (server) => server.reply(200, {}));

      final response = await ApiClient().dio.get('/api/employees/me');

      expect(
        response.requestOptions.headers['Authorization'],
        'Bearer header.payload.signature',
      );
      expect(storageCalls.map((call) => call.method), contains('read'));
      expect(
        (storageCalls.first.arguments as Map)['key'],
        'jwt_token',
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

      expect(error.message, '알 수 없는 오류가 발생했습니다.');
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

    // 발견한 문제: message 값이 문자열이 아니면(검증 오류 상세를 객체로 내려주는 경우 등)
    // error.copyWith(message: ...)의 암묵적 String? 캐스팅이 실패해
    // DioExceptionType.unknown 으로 바뀌고 서버가 준 정보가 전부 사라진다.
    // 프로덕션 코드는 손대지 않고 현재 동작만 기록한다.
    test('message 값이 문자열이 아니면 타입 오류로 바뀌어 원래 응답 정보가 사라진다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(400, {
          'message': {'employeeNumber': '필수 값입니다'}
        }),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.type, DioExceptionType.unknown);
      expect(error.error, isA<TypeError>());
      expect(error.response, isNull);
    });
  });

  group('401 응답', () {
    test('401 응답의 message가 그대로 전달되고 저장된 토큰은 그대로 남는다', () async {
      storedToken = 'expired.token';
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': '인증 정보가 유효하지 않습니다.'}),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(error.message, '인증 정보가 유효하지 않습니다.');
      // 현재 ApiClient에는 401 자동 로그아웃/토큰 삭제 처리가 없다.
      expect(storedToken, 'expired.token');
      expect(storageCalls.map((call) => call.method), isNot(contains('delete')));
    });

    test('401 응답 본문이 비어 있으면 네트워크 오류 메시지가 된다', () async {
      storedToken = 'expired.token';
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, null),
      );

      final error = await _captureDioException(
        () => ApiClient().dio.get('/api/employees/me'),
      );

      expect(error.response?.statusCode, 401);
      expect(error.message, '네트워크 오류가 발생했습니다.');
    });
  });

  group('토큰 저장소', () {
    test('saveToken은 jwt_token 키로 값을 저장한다', () async {
      await ApiClient().saveToken('new.jwt.token');

      final write = storageCalls.firstWhere((call) => call.method == 'write');
      expect((write.arguments as Map)['key'], 'jwt_token');
      expect((write.arguments as Map)['value'], 'new.jwt.token');
      expect(storedToken, 'new.jwt.token');
    });

    test('getToken은 저장된 값을 돌려주고, 없으면 null을 돌려준다', () async {
      expect(await ApiClient().getToken(), isNull);

      storedToken = 'saved.jwt.token';
      expect(await ApiClient().getToken(), 'saved.jwt.token');
    });

    test('clearToken은 jwt_token 키를 삭제한다', () async {
      storedToken = 'saved.jwt.token';

      await ApiClient().clearToken();

      final delete = storageCalls.firstWhere((call) => call.method == 'delete');
      expect((delete.arguments as Map)['key'], 'jwt_token');
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
