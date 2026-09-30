import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../../helpers/fixture_reader.dart';

/// AuthRepository 특성화 테스트.
///
/// 이 리포지토리만 Dio가 아니라 ApiClient를 받으므로 실제 싱글턴을 그대로 쓰고,
/// JWT 저장소(플랫폼 채널)는 메모리 저장소처럼 동작하도록 모킹한다.
/// 덕분에 로그인 성공 시 토큰이 실제로 저장되는지까지 확인할 수 있다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late DioAdapter dioAdapter;
  late AuthRepository repository;
  late List<RequestOptions> sentRequests;
  late List<MethodCall> storageCalls;
  late Interceptor captureInterceptor;
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

    sentRequests = <RequestOptions>[];
    captureInterceptor = InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    });
    ApiClient().dio.interceptors.add(captureInterceptor);

    dioAdapter = DioAdapter(dio: ApiClient().dio);
    repository = AuthRepository(apiClient: ApiClient());
  });

  tearDown(() {
    // 싱글턴 dio에 붙인 인터셉터가 다음 테스트로 넘어가지 않도록 걷어낸다.
    ApiClient().dio.interceptors.remove(captureInterceptor);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  RequestOptions lastRequest() => sentRequests.last;

  List<MethodCall> writeCalls() =>
      storageCalls.where((call) => call.method == 'write').toList();

  group('signIn', () {
    test('POST /api/auth/signin에 사번과 비밀번호를 실어 보낸다', () async {
      dioAdapter.onPost(
        '/api/auth/signin',
        (server) => server.reply(200, fixtureJson('auth/login_response.json')),
        data: {'employeeNumber': 'A0001', 'password': 'pw1234!'},
      );

      await repository.signIn('A0001', 'pw1234!');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/auth/signin');
      expect(lastRequest().data,
          {'employeeNumber': 'A0001', 'password': 'pw1234!'});
    });

    test('응답을 LoginResponse로 매핑한다', () async {
      dioAdapter.onPost(
        '/api/auth/signin',
        (server) => server.reply(200, fixtureJson('auth/login_response.json')),
        data: {'employeeNumber': 'A0001', 'password': 'pw1234!'},
      );

      final response = await repository.signIn('A0001', 'pw1234!');

      expect(response.token, 'header.payload.signature');
      expect(response.employeeId, 7);
      expect(response.name, '홍길동');
      expect(response.role, 'ADMIN');
      expect(response.isAdmin, isTrue);
    });

    test('로그인에 성공하면 토큰을 저장한다', () async {
      dioAdapter.onPost(
        '/api/auth/signin',
        (server) => server.reply(200, fixtureJson('auth/login_response.json')),
        data: {'employeeNumber': 'A0001', 'password': 'pw1234!'},
      );

      await repository.signIn('A0001', 'pw1234!');

      expect(writeCalls(), hasLength(1));
      expect((writeCalls().single.arguments as Map)['key'], 'jwt_token');
      expect((writeCalls().single.arguments as Map)['value'],
          'header.payload.signature');
      expect(await repository.getToken(), 'header.payload.signature');
    });

    test('로그인에 실패하면 예외가 전파되고 토큰을 저장하지 않는다', () async {
      dioAdapter.onPost(
        '/api/auth/signin',
        (server) =>
            server.reply(401, {'message': '사번 또는 비밀번호가 올바르지 않습니다.'}),
        data: {'employeeNumber': 'A0001', 'password': 'wrong'},
      );

      await expectLater(
        repository.signIn('A0001', 'wrong'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', '사번 또는 비밀번호가 올바르지 않습니다.')),
      );
      expect(writeCalls(), isEmpty);
      expect(storedToken, isNull);
    });
  });

  group('fetchMyInfo', () {
    test('GET /api/employees/me로 조회하고 Employee로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(200, fixtureJson('admin/employee.json')),
      );

      final employee = await repository.fetchMyInfo();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/employees/me');
      expect(employee.employeeNumber, 'A0001');
      expect(employee.name, '홍길동');
      expect(employee.position, '과장');
      expect(employee.remainingLeaveDays, 11.5);
      expect(employee.approverName, '김결재');
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/employees/me',
        (server) => server.reply(401, {'message': '인증이 필요합니다.'}),
      );

      await expectLater(
        repository.fetchMyInfo(),
        throwsA(isA<DioException>()
            .having((e) => e.message, 'message', '인증이 필요합니다.')),
      );
    });
  });

  group('signUp', () {
    test('POST /api/auth/signup에 사번과 비밀번호를 실어 보낸다', () async {
      dioAdapter.onPost(
        '/api/auth/signup',
        (server) => server.reply(200, {}),
        data: {'employeeNumber': 'A0009', 'password': 'newPw1234!'},
      );

      await repository.signUp('A0009', 'newPw1234!');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/auth/signup');
      expect(lastRequest().data,
          {'employeeNumber': 'A0009', 'password': 'newPw1234!'});
      // 등록은 토큰을 저장하지 않는다.
      expect(writeCalls(), isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/auth/signup',
        (server) => server.reply(400, {'message': '이미 등록된 사번입니다.'}),
        data: {'employeeNumber': 'A0009', 'password': 'newPw1234!'},
      );

      await expectLater(
        repository.signUp('A0009', 'newPw1234!'),
        throwsA(isA<DioException>()
            .having((e) => e.message, 'message', '이미 등록된 사번입니다.')),
      );
    });
  });

  group('sendPasswordResetEmail', () {
    test('POST /api/auth/forgot-password에 사번과 이메일을 실어 보낸다', () async {
      dioAdapter.onPost(
        '/api/auth/forgot-password',
        (server) => server.reply(200, {}),
        data: {'employeeNumber': 'A0001', 'email': 'hong@example.com'},
      );

      await repository.sendPasswordResetEmail('A0001', 'hong@example.com');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/auth/forgot-password');
      expect(lastRequest().data,
          {'employeeNumber': 'A0001', 'email': 'hong@example.com'});
    });

    test('200이 아닌 성공 응답이면 발송 실패 예외를 던진다', () async {
      dioAdapter.onPost(
        '/api/auth/forgot-password',
        (server) => server.reply(202, {}),
        data: {'employeeNumber': 'A0001', 'email': 'hong@example.com'},
      );

      await expectLater(
        repository.sendPasswordResetEmail('A0001', 'hong@example.com'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'toString', contains('발송 실패'))),
      );
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/auth/forgot-password',
        (server) => server.reply(404, {'message': '등록된 이메일이 아닙니다.'}),
        data: {'employeeNumber': 'A0001', 'email': 'hong@example.com'},
      );

      await expectLater(
        repository.sendPasswordResetEmail('A0001', 'hong@example.com'),
        throwsA(isA<DioException>()
            .having((e) => e.message, 'message', '등록된 이메일이 아닙니다.')),
      );
    });
  });

  group('findId', () {
    test('POST /api/auth/find-id에 이름과 이메일을 실어 보낸다', () async {
      dioAdapter.onPost(
        '/api/auth/find-id',
        (server) => server.reply(200, {}),
        data: {'name': '홍길동', 'email': 'hong@example.com'},
      );

      await repository.findId('홍길동', 'hong@example.com');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/auth/find-id');
      expect(lastRequest().data, {'name': '홍길동', 'email': 'hong@example.com'});
    });

    test('200이 아닌 성공 응답이면 발송 실패 예외를 던진다', () async {
      dioAdapter.onPost(
        '/api/auth/find-id',
        (server) => server.reply(204, {}),
        data: {'name': '홍길동', 'email': 'hong@example.com'},
      );

      await expectLater(
        repository.findId('홍길동', 'hong@example.com'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'toString', contains('발송 실패'))),
      );
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/auth/find-id',
        (server) => server.reply(404, {'message': '일치하는 사원이 없습니다.'}),
        data: {'name': '홍길동', 'email': 'hong@example.com'},
      );

      await expectLater(
        repository.findId('홍길동', 'hong@example.com'),
        throwsA(isA<DioException>()
            .having((e) => e.message, 'message', '일치하는 사원이 없습니다.')),
      );
    });
  });

  group('토큰 위임', () {
    test('getToken은 ApiClient에 저장된 토큰을 그대로 돌려준다', () async {
      expect(await repository.getToken(), isNull);

      storedToken = 'saved.jwt.token';
      expect(await repository.getToken(), 'saved.jwt.token');
    });

    test('clearToken은 저장된 토큰을 삭제한다', () async {
      storedToken = 'saved.jwt.token';

      await repository.clearToken();

      expect(storageCalls.map((call) => call.method), contains('delete'));
      expect(storedToken, isNull);
    });
  });
}
