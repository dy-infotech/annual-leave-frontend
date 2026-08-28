import 'package:annual_leave_frontend/features/admin/repositories/signup_manage_repository.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// SignupManageRepository 특성화 테스트.
///
/// 사용자 등록 요청 본문의 키 구성과 에러 전파를 기록한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late SignupManageRepository repository;

  AdminAuthRegisterRequest request() => AdminAuthRegisterRequest(
        employeeNumber: 'A0009',
        name: '신입사원',
        department: '경영지원부',
        team: 'SI사업팀',
        position: '사원',
        role: 'EMPLOYEE',
        email: 'newbie@example.com',
        hireDate: '2026-09-01',
      );

  const expectedBody = {
    'employeeNumber': 'A0009',
    'name': '신입사원',
    'department': '경영지원부',
    'team': 'SI사업팀',
    'position': '사원',
    'role': 'EMPLOYEE',
    'email': 'newbie@example.com',
    'hireDate': '2026-09-01',
  };

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = SignupManageRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  group('registerUser', () {
    test('POST /api/admin/auth/register에 등록 본문 8개 키를 그대로 보낸다', () async {
      dioAdapter.onPost(
        '/api/admin/auth/register',
        (server) => server.reply(200, {}),
        data: expectedBody,
      );

      await repository.registerUser(request());

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/admin/auth/register');
      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().data, expectedBody);
      expect((lastRequest().data as Map).keys, hasLength(8));
    });

    test('사번 중복 등 에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/auth/register',
        (server) => server.reply(409, {'message': '이미 등록된 사번입니다.'}),
        data: expectedBody,
      );

      await expectLater(
        repository.registerUser(request()),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 409)),
      );
    });

    test('권한 없음 응답도 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/auth/register',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
        data: expectedBody,
      );

      await expectLater(
        repository.registerUser(request()),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 403)),
      );
    });
  });
}
