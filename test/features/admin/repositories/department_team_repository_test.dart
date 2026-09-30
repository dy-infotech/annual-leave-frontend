import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/repositories/department_team_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../../helpers/fixture_reader.dart';

/// DepartmentTeamRepository 특성화 테스트.
///
/// 부서 4개, 팀 4개, 담당자 검색 1개 총 9개 엔드포인트의 요청 형태와
/// 응답 매핑, 검색어 trim 분기를 기록한다.
void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late List<RequestOptions> sentRequests;
  late DepartmentTeamRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    sentRequests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sentRequests.add(options);
      handler.next(options);
    }));
    dioAdapter = DioAdapter(dio: dio);
    repository = DepartmentTeamRepository(dio: dio);
  });

  RequestOptions lastRequest() => sentRequests.last;

  group('fetchDepartments', () {
    test('GET /api/admin/departments를 호출하고 Department 목록으로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/admin/departments',
        (server) => server.reply(200, [
          fixtureJson('admin/department.json'),
          fixtureJson('admin/department.json')
            ..['departmentId'] = 1
            ..['departmentName'] = '대표이사',
        ]),
      );

      final departments = await repository.fetchDepartments();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/departments');
      expect(lastRequest().queryParameters, isEmpty);
      expect(departments, hasLength(2));
      expect(departments.first, isA<Department>());
      expect(departments.first.departmentId, 2);
      expect(departments.first.departmentName, '경영지원부');
      expect(departments.first.enabled, isTrue);
      expect(departments.first.isProtected, isFalse);
      expect(departments.last.isProtected, isTrue);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/departments',
        (server) => server.reply(403, {'message': '대표이사만 사용할 수 있습니다.'}),
      );

      await expectLater(
        repository.fetchDepartments(),
        throwsA(isA<DioException>().having(
            (e) => e.response?.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('createDepartment', () {
    test('POST /api/admin/departments에 departmentName을 보낸다', () async {
      dioAdapter.onPost(
        '/api/admin/departments',
        (server) => server.reply(200, {}),
        data: {'departmentName': '연구개발부'},
      );

      await repository.createDepartment('연구개발부');

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/admin/departments');
      expect(lastRequest().data, {'departmentName': '연구개발부'});
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/departments',
        (server) => server.reply(409, {'message': '이미 있는 부서명입니다.'}),
        data: {'departmentName': '연구개발부'},
      );

      await expectLater(
        repository.createDepartment('연구개발부'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('updateDepartment', () {
    test('PUT /api/admin/departments/{departmentId}에 departmentName을 보낸다',
        () async {
      dioAdapter.onPut(
        '/api/admin/departments/2',
        (server) => server.reply(200, {}),
        data: {'departmentName': '경영지원본부'},
      );

      await repository.updateDepartment(2, '경영지원본부');

      expect(lastRequest().method, 'PUT');
      expect(lastRequest().path, '/api/admin/departments/2');
      expect(lastRequest().data, {'departmentName': '경영지원본부'});
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPut(
        '/api/admin/departments/1',
        (server) => server.reply(400, {'message': '대표이사 부서는 수정할 수 없습니다.'}),
        data: {'departmentName': '변경'},
      );

      await expectLater(
        repository.updateDepartment(1, '변경'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('deleteDepartment', () {
    test('DELETE /api/admin/departments/{departmentId}를 본문 없이 호출한다', () async {
      dioAdapter.onDelete(
        '/api/admin/departments/2',
        (server) => server.reply(200, null),
      );

      await repository.deleteDepartment(2);

      expect(lastRequest().method, 'DELETE');
      expect(lastRequest().path, '/api/admin/departments/2');
      expect(lastRequest().data, isNull);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onDelete(
        '/api/admin/departments/1',
        (server) => server.reply(400, {'message': '소속 팀이 있어 삭제할 수 없습니다.'}),
      );

      await expectLater(
        repository.deleteDepartment(1),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('fetchTeams', () {
    test('GET /api/admin/teams를 호출하고 Team 목록으로 매핑한다', () async {
      dioAdapter.onGet(
        '/api/admin/teams',
        (server) => server.reply(200, [fixtureJson('admin/team.json')]),
      );

      final teams = await repository.fetchTeams();

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/teams');
      expect(teams, hasLength(1));
      expect(teams.first, isA<Team>());
      expect(teams.first.teamId, 3);
      expect(teams.first.teamName, 'SI사업팀');
      expect(teams.first.departmentId, 2);
      expect(teams.first.departmentName, '경영지원부');
      expect(teams.first.parentTeamId, 1);
      expect(teams.first.parentTeamName, '대표이사');
      expect(teams.first.managers, hasLength(1));
      expect(teams.first.managers.first.name, '홍길동');
      expect(teams.first.managers.first.display, '홍길동 부장');
      expect(teams.first.isRoot, isFalse);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/teams',
        (server) => server.reply(403, {'message': '대표이사만 사용할 수 있습니다.'}),
      );

      await expectLater(
        repository.fetchTeams(),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('createTeam', () {
    test('POST /api/admin/teams에 팀 등록 본문을 보낸다', () async {
      dioAdapter.onPost(
        '/api/admin/teams',
        (server) => server.reply(200, {}),
        data: {
          'teamName': '신규팀',
          'projectManagerId': 5,
          'departmentId': 2,
          'parentTeamId': 1,
        },
      );

      await repository.createTeam(TeamCreateRequest(
        teamName: '신규팀',
        projectManagerId: 5,
        departmentId: 2,
        parentTeamId: 1,
      ));

      expect(lastRequest().method, 'POST');
      expect(lastRequest().path, '/api/admin/teams');
      expect(lastRequest().data, {
        'teamName': '신규팀',
        'projectManagerId': 5,
        'departmentId': 2,
        'parentTeamId': 1,
      });
    });

    test('parentTeamId가 없으면 본문에서 그 키가 빠진다', () async {
      dioAdapter.onPost(
        '/api/admin/teams',
        (server) => server.reply(200, {}),
        data: {
          'teamName': '신규팀',
          'projectManagerId': 5,
          'departmentId': 2,
        },
      );

      await repository.createTeam(TeamCreateRequest(
        teamName: '신규팀',
        projectManagerId: 5,
        departmentId: 2,
      ));

      expect((lastRequest().data as Map).containsKey('parentTeamId'), isFalse);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPost(
        '/api/admin/teams',
        (server) => server.reply(409, {'message': '이미 있는 팀명입니다.'}),
        data: {
          'teamName': '신규팀',
          'projectManagerId': 5,
          'departmentId': 2,
        },
      );

      await expectLater(
        repository.createTeam(TeamCreateRequest(
          teamName: '신규팀',
          projectManagerId: 5,
          departmentId: 2,
        )),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('updateTeam', () {
    test('PUT /api/admin/teams/{teamId}에 수정 본문을 보낸다', () async {
      dioAdapter.onPut(
        '/api/admin/teams/3',
        (server) => server.reply(200, {}),
        data: {'teamName': 'SI사업1팀', 'projectManagerId': 5},
      );

      await repository.updateTeam(
        3,
        TeamUpdateRequest(teamName: 'SI사업1팀', projectManagerId: 5),
      );

      expect(lastRequest().method, 'PUT');
      expect(lastRequest().path, '/api/admin/teams/3');
      expect(lastRequest().data, {'teamName': 'SI사업1팀', 'projectManagerId': 5});
    });

    test('지정하지 않은 필드는 본문에서 빠진다', () async {
      dioAdapter.onPut(
        '/api/admin/teams/3',
        (server) => server.reply(200, {}),
        data: {'departmentId': 2},
      );

      await repository.updateTeam(3, TeamUpdateRequest(departmentId: 2));

      expect(lastRequest().data, {'departmentId': 2});
    });

    test('아무 필드도 없으면 빈 본문을 보낸다', () async {
      dioAdapter.onPut(
        '/api/admin/teams/3',
        (server) => server.reply(200, {}),
        data: {},
      );

      await repository.updateTeam(3, TeamUpdateRequest());

      // 리포지토리는 isEmpty를 검사하지 않아 빈 본문 요청이 그대로 나간다.
      expect(lastRequest().data, isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onPut(
        '/api/admin/teams/1',
        (server) => server.reply(400, {'message': '대표이사 팀은 수정할 수 없습니다.'}),
        data: {'teamName': '변경'},
      );

      await expectLater(
        repository.updateTeam(1, TeamUpdateRequest(teamName: '변경')),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('deleteTeam', () {
    test('DELETE /api/admin/teams/{teamId}를 본문 없이 호출한다', () async {
      dioAdapter.onDelete(
        '/api/admin/teams/3',
        (server) => server.reply(200, null),
      );

      await repository.deleteTeam(3);

      expect(lastRequest().method, 'DELETE');
      expect(lastRequest().path, '/api/admin/teams/3');
      expect(lastRequest().data, isNull);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onDelete(
        '/api/admin/teams/1',
        (server) => server.reply(400, {'message': '소속 사원이 있어 삭제할 수 없습니다.'}),
      );

      await expectLater(
        repository.deleteTeam(1),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('searchEmployees', () {
    test('검색어가 있으면 trim해서 searchParam 쿼리로 보낸다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, [fixtureJson('admin/employee.json')]),
        queryParameters: {'searchParam': '홍길동'},
      );

      final employees = await repository.searchEmployees('  홍길동  ');

      expect(lastRequest().method, 'GET');
      expect(lastRequest().path, '/api/admin/employees/all');
      expect(lastRequest().queryParameters, {'searchParam': '홍길동'});
      expect(employees.first.name, '홍길동');
    });

    test('검색어가 null이면 쿼리 파라미터 없이 전체를 조회한다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
      );

      await repository.searchEmployees(null);

      expect(lastRequest().queryParameters, isEmpty);
      expect(lastRequest().uri.hasQuery, isFalse);
    });

    test('검색어가 공백뿐이면 쿼리 파라미터 없이 전체를 조회한다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(200, []),
      );

      await repository.searchEmployees('   ');

      expect(lastRequest().queryParameters, isEmpty);
    });

    test('에러 응답은 예외로 전파된다', () async {
      dioAdapter.onGet(
        '/api/admin/employees/all',
        (server) => server.reply(403, {'message': '권한이 없습니다.'}),
      );

      await expectLater(
        repository.searchEmployees('홍'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
