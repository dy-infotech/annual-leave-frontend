import 'package:annual_leave_frontend/features/employee/repositories/employee_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// EmployeeRepository 특성화 테스트.
///
/// PATCH 2개의 경로와 본문 키 구성, 에러 전파를 기록한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late EmployeeRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = EmployeeRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  group('changePassword', () {
    test('PATCH /api/employees/me/password에 현재/새 비밀번호를 보낸다', () async {
      dioAdapter.onPatch(
        '/api/employees/me/password',
        (server) => server.reply(200, {}),
        data: {'currentPassword': 'oldPw1234!', 'newPassword': 'newPw1234!'},
      );

      await repository.changePassword(
        currentPassword: 'oldPw1234!',
        newPassword: 'newPw1234!',
      );

      expect(lastRequest().method, 'PATCH');
      expect(lastRequest().path, '/api/employees/me/password');
      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().data, {
        'currentPassword': 'oldPw1234!',
        'newPassword': 'newPw1234!',
      });
      expect((lastRequest().data as Map).keys,
          containsAll(['currentPassword', 'newPassword']));
    });

    test('현재 비밀번호가 틀리면 예외로 전파된다', () async {
      dioAdapter.onPatch(
        '/api/employees/me/password',
        (server) => server.reply(400, {'message': '현재 비밀번호가 일치하지 않습니다.'}),
        data: {'currentPassword': 'wrong', 'newPassword': 'newPw1234!'},
      );

      await expectLater(
        repository.changePassword(
          currentPassword: 'wrong',
          newPassword: 'newPw1234!',
        ),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('changeEmail', () {
    test('PATCH /api/employees/me/email에 email 키 하나만 보낸다', () async {
      dioAdapter.onPatch(
        '/api/employees/me/email',
        (server) => server.reply(200, {}),
        data: {'email': 'hong@example.com'},
      );

      await repository.changeEmail('hong@example.com');

      expect(lastRequest().method, 'PATCH');
      expect(lastRequest().path, '/api/employees/me/email');
      expect(lastRequest().data, {'email': 'hong@example.com'});
      expect((lastRequest().data as Map).keys, hasLength(1));
    });

    test('이메일 형식 오류 응답은 예외로 전파된다', () async {
      dioAdapter.onPatch(
        '/api/employees/me/email',
        (server) => server.reply(400, {'message': '이메일 형식이 올바르지 않습니다.'}),
        data: {'email': 'not-an-email'},
      );

      await expectLater(
        repository.changeEmail('not-an-email'),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 400)),
      );
    });

    test('인증 만료 응답도 예외로 전파된다', () async {
      dioAdapter.onPatch(
        '/api/employees/me/email',
        (server) => server.reply(401, {'message': '인증이 필요합니다.'}),
        data: {'email': 'hong@example.com'},
      );

      await expectLater(
        repository.changeEmail('hong@example.com'),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 401)),
      );
    });
  });
}
