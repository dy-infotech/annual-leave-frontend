import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../../helpers/fixture_reader.dart';

/// AdminEmployeeRepository 특성화 테스트.
///
/// 검색어가 없을 때 queryParameters를 null로 넘기는 분기와
/// 상태코드를 그대로 돌려주는 수정 API 동작을 기록한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late AdminEmployeeRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = AdminEmployeeRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  group('fetchEmployees', () {
    test('검색어가 없으면 쿼리 파라미터 없이 GET /api/admin/employees/all을 호출한다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, [fixtureJson('admin/employee.json')]),
      );

      await repository.fetchEmployees();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/employees/all');
      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().uri.hasQuery, isFalse);
    });

    test('검색어가 빈 문자열이어도 쿼리 파라미터 없이 호출한다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
      );

      await repository.fetchEmployees(searchParam: '');

      expect(lastRequest().queryParameters, isEmpty);
    });

    test('검색어가 있으면 searchParam 쿼리로 실린다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
        queryParameters: {'searchParam': '홍길동'},
      );

      await repository.fetchEmployees(searchParam: '홍길동');

      expect(lastRequest().queryParameters, {'searchParam': '홍길동'});
    });

    test('공백만 있는 검색어는 그대로 쿼리에 실린다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
        queryParameters: {'searchParam': '  '},
      );

      await repository.fetchEmployees(searchParam: '  ');

      // 이 리포지토리는 trim을 하지 않아 공백 검색어가 그대로 전달된다.
      expect(lastRequest().queryParameters, {'searchParam': '  '});
    });

    test('배열 응답을 Employee 목록으로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, [fixtureJson('admin/employee.json')]),
      );

      final employees = await repository.fetchEmployees();

      expect(employees, hasLength(1));
      expect(employees.first, isA<Employee>());
      expect(employees.first.employeeId, 5);
      expect(employees.first.employeeNumber, 'A0001');
      expect(employees.first.name, '홍길동');
      expect(employees.first.teamList, ['SI사업팀', 'BI사업팀']);
      expect(employees.first.currTotalLeaveDays, 15.0);
      expect(employees.first.remainingLeaveDays, 11.5);
    });

    test('빈 배열 응답은 빈 목록이 된다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
      );

      expect(await repository.fetchEmployees(), isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
      );

      await expectLater(
        repository.fetchEmployees(),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('updateEmployee', () {
    test('PUT /api/admin/employees/{employeeNumber}에 수정 본문을 보낸다', () async {
      dioAdapter.onPut(
        '/api/admin/employees/A0001',
        (server) => server.reply(200, {}),
        data: {'position': '차장', 'team': 'BI사업팀'},
      );

      await repository
          .updateEmployee('A0001', {'position': '차장', 'team': 'BI사업팀'});

      expect(lastRequest().method, 'PUT');
      expect(lastRequest().path, '/api/admin/employees/A0001');
      expect(lastRequest().data, {'position': '차장', 'team': 'BI사업팀'});
    });

    test('응답 상태코드를 그대로 돌려준다', () async {
      dioAdapter.onPut(
        '/api/admin/employees/A0001',
        (server) => server.reply(204, null),
        data: {'position': '차장'},
      );

      expect(
        await repository.updateEmployee('A0001', {'position': '차장'}),
        204,
      );
    });

    test('에러 응답은 상태코드가 아니라 예외로 전파된다', () async {
      dioAdapter.onPut(
        '/api/admin/employees/A0001',
        (server) => server.reply(400, {'message': '잘못된 요청입니다.'}),
        data: {'position': '차장'},
      );

      await expectLater(
        repository.updateEmployee('A0001', {'position': '차장'}),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 400)),
      );
    });
  });
}
