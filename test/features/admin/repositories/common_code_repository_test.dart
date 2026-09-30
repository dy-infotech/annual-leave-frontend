import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// CommonCodeRepository 특성화 테스트.
///
/// 응답 Map을 가공 없이 그대로 돌려주는 동작을 기록한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late CommonCodeRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = CommonCodeRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  group('fetchCommonCodes', () {
    test('GET /api/admin/auth/common을 쿼리 없이 호출한다', () async {
      dioAdapter.onGet(
        '/api/admin/auth/common',
        (server) => server.reply(200, {}),
      );

      await repository.fetchCommonCodes();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/auth/common');
      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().data, isNull);
    });

    test('응답 Map을 가공 없이 그대로 돌려준다', () async {
      dioAdapter.onGet(
        '/api/admin/auth/common',
        (server) => server.reply(200, {
          'departmentList': ['경영지원부', '연구개발부'],
          'teamList': ['SI사업팀', 'BI사업팀'],
          'positionList': ['사원', '대리', '과장'],
          'roleList': ['EMPLOYEE', 'ADMIN'],
        }),
      );

      final codes = await repository.fetchCommonCodes();

      expect(codes.keys,
          containsAll(['departmentList', 'teamList', 'positionList', 'roleList']));
      expect(codes['departmentList'], ['경영지원부', '연구개발부']);
      expect(codes['teamList'], ['SI사업팀', 'BI사업팀']);
      expect(codes['positionList'], ['사원', '대리', '과장']);
      expect(codes['roleList'], ['EMPLOYEE', 'ADMIN']);
    });

    test('빈 Map 응답도 그대로 돌려준다', () async {
      dioAdapter.onGet(
        '/api/admin/auth/common',
        (server) => server.reply(200, {}),
      );

      expect(await repository.fetchCommonCodes(), isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/auth/common',
        (server) => server.reply(401, {'message': '인증이 필요합니다.'}),
      );

      await expectLater(
        repository.fetchCommonCodes(),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 401)),
      );
    });
  });
}
