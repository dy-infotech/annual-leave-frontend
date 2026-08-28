import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/department_team_repository.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM003_M01_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

/// DepartmentTeamRepository 인메모리 페이크. (이 화면 전용이라 로컬에 둔다)
class _FakeDepartmentTeamRepository implements DepartmentTeamRepository {
  List<Department> departmentsToReturn = [];
  List<Team> teamsToReturn = [];
  List<Employee> employeesToReturn = [];

  Object? fetchDepartmentsError;
  Object? fetchTeamsError;
  Object? createDepartmentError;
  Object? updateDepartmentError;
  Object? deleteDepartmentError;
  Object? createTeamError;
  Object? updateTeamError;
  Object? deleteTeamError;

  final List<String> createdDepartments = [];
  final List<Map<String, Object>> updatedDepartments = [];
  final List<int> deletedDepartmentIds = [];
  final List<TeamCreateRequest> createdTeams = [];
  final List<Map<String, Object>> updatedTeams = [];
  final List<int> deletedTeamIds = [];
  final List<String?> employeeSearches = [];

  @override
  Future<List<Department>> fetchDepartments() async {
    if (fetchDepartmentsError != null) throw fetchDepartmentsError!;
    return departmentsToReturn;
  }

  @override
  Future<void> createDepartment(String departmentName) async {
    createdDepartments.add(departmentName);
    if (createDepartmentError != null) throw createDepartmentError!;
  }

  @override
  Future<void> updateDepartment(int departmentId, String departmentName) async {
    updatedDepartments.add({'id': departmentId, 'name': departmentName});
    if (updateDepartmentError != null) throw updateDepartmentError!;
  }

  @override
  Future<void> deleteDepartment(int departmentId) async {
    deletedDepartmentIds.add(departmentId);
    if (deleteDepartmentError != null) throw deleteDepartmentError!;
  }

  @override
  Future<List<Team>> fetchTeams() async {
    if (fetchTeamsError != null) throw fetchTeamsError!;
    return teamsToReturn;
  }

  @override
  Future<void> createTeam(TeamCreateRequest request) async {
    createdTeams.add(request);
    if (createTeamError != null) throw createTeamError!;
  }

  @override
  Future<void> updateTeam(int teamId, TeamUpdateRequest request) async {
    updatedTeams.add({'id': teamId, 'request': request});
    if (updateTeamError != null) throw updateTeamError!;
  }

  @override
  Future<void> deleteTeam(int teamId) async {
    deletedTeamIds.add(teamId);
    if (deleteTeamError != null) throw deleteTeamError!;
  }

  @override
  Future<List<Employee>> searchEmployees(String? keyword) async {
    employeeSearches.add(keyword);
    return employeesToReturn;
  }
}

DioException dioError({String? message}) => DioException(
      requestOptions: RequestOptions(path: '/api/admin/departments'),
      message: message,
    );

void main() {
  late _FakeDepartmentTeamRepository repository;

  Department dept({int id = 2, String name = '경영지원부'}) =>
      Department.fromJson(fixtureJson('admin/department.json')
        ..['departmentId'] = id
        ..['departmentName'] = name);

  Team team({int id = 3, String name = 'SI사업팀', int? departmentId = 2}) =>
      Team.fromJson(fixtureJson('admin/team.json')
        ..['teamId'] = id
        ..['teamName'] = name
        ..['departmentId'] = departmentId);

  setUp(() {
    repository = _FakeDepartmentTeamRepository();
  });

  DepartmentTeamViewModel build() =>
      DepartmentTeamViewModel(repository: repository);

  group('DepartmentTeamViewModel - messageOf', () {
    test('DioException의 서버 메시지가 있으면 그것을 쓴다', () {
      final vm = build();

      expect(
        vm.messageOf(dioError(message: '이미 사용 중인 부서명입니다.'), '기본 문구'),
        '이미 사용 중인 부서명입니다.',
      );
    });

    test('DioException이라도 메시지가 없거나 공백뿐이면 기본 문구를 쓴다', () {
      final vm = build();

      expect(vm.messageOf(dioError(), '기본 문구'), '기본 문구');
      expect(vm.messageOf(dioError(message: '   '), '기본 문구'), '기본 문구');
    });

    test('DioException이 아니면 기본 문구를 쓴다', () {
      final vm = build();

      expect(vm.messageOf(Exception('boom'), '기본 문구'), '기본 문구');
      expect(vm.messageOf('문자열 에러', '기본 문구'), '기본 문구');
    });
  });

  group('DepartmentTeamViewModel - 목록 조회', () {
    test('fetchDepartments 성공 - 목록을 채우고 에러를 비운다', () async {
      repository.departmentsToReturn = [dept()];

      final vm = build();
      await vm.fetchDepartments();

      expect(vm.departments, hasLength(1));
      expect(vm.deptError, isNull);
      expect(vm.isDeptLoading, isFalse);
    });

    test('fetchDepartments 실패 - 서버 메시지를 에러로 남긴다', () async {
      repository.fetchDepartmentsError = dioError(message: '권한이 없습니다.');

      final vm = build();
      await vm.fetchDepartments();

      expect(vm.deptError, '권한이 없습니다.');
      expect(vm.isDeptLoading, isFalse);
    });

    test('fetchDepartments 실패 - 서버 메시지가 없으면 기본 문구를 남긴다', () async {
      repository.fetchDepartmentsError = Exception('timeout');

      final vm = build();
      await vm.fetchDepartments();

      expect(vm.deptError, '부서 목록을 불러오지 못했습니다.');
    });

    test('fetchTeams 실패 - 기본 문구를 남긴다', () async {
      repository.fetchTeamsError = Exception('timeout');

      final vm = build();
      await vm.fetchTeams();

      expect(vm.teamError, '팀 목록을 불러오지 못했습니다.');
      expect(vm.isTeamLoading, isFalse);
    });

    test('fetchTeams - 필터로 걸어둔 부서에 팀이 남아 있으면 필터를 유지한다', () async {
      repository.teamsToReturn = [team(departmentId: 2)];

      final vm = build();
      vm.setTeamFilter(2);
      await vm.fetchTeams();

      expect(vm.teamFilterDeptId, 2);
    });

    test('fetchTeams - 필터로 걸어둔 부서가 사라지면 전체로 되돌린다', () async {
      repository.teamsToReturn = [team(departmentId: 7)];

      final vm = build();
      vm.setTeamFilter(2);
      await vm.fetchTeams();

      expect(vm.teamFilterDeptId, isNull);
    });

    test('fetchTeams - 조회 실패 시에는 필터를 건드리지 않는다', () async {
      repository.fetchTeamsError = Exception('timeout');

      final vm = build();
      vm.setTeamFilter(2);
      await vm.fetchTeams();

      expect(vm.teamFilterDeptId, 2);
    });

    test('teamsOfDepartment - 부서 아이디로 팀을 걸러낸다', () async {
      repository.teamsToReturn = [
        team(id: 3, departmentId: 2),
        team(id: 4, name: 'BI사업팀', departmentId: 7),
      ];

      final vm = build();
      await vm.fetchTeams();

      expect(vm.teamsOfDepartment(2).map((t) => t.teamId), [3]);
      expect(vm.teamsOfDepartment(7).map((t) => t.teamId), [4]);
      expect(vm.teamsOfDepartment(99), isEmpty);
    });

    test('refreshAll - 부서와 팀을 함께 조회한다', () async {
      repository.departmentsToReturn = [dept()];
      repository.teamsToReturn = [team()];

      final vm = build();
      await vm.refreshAll();

      expect(vm.departments, hasLength(1));
      expect(vm.teams, hasLength(1));
    });
  });

  group('DepartmentTeamViewModel - 부서 저장/삭제', () {
    test('submitDepartment - origin이 없으면 등록, 있으면 수정 API를 부른다', () async {
      final vm = build();

      expect(await vm.submitDepartment(null, '신규부서'), isNull);
      expect(repository.createdDepartments, ['신규부서']);

      expect(await vm.submitDepartment(dept(), '이름변경'), isNull);
      expect(repository.updatedDepartments, [
        {'id': 2, 'name': '이름변경'}
      ]);
    });

    test('submitDepartment 실패 - 등록과 수정의 기본 문구가 다르다', () async {
      repository.createDepartmentError = Exception('500');
      repository.updateDepartmentError = Exception('500');

      final vm = build();

      expect(await vm.submitDepartment(null, '신규부서'), '부서 등록에 실패했습니다.');
      expect(await vm.submitDepartment(dept(), '이름변경'), '부서 수정에 실패했습니다.');
    });

    test('submitDepartment 실패 - 서버 메시지가 있으면 그것을 돌려준다', () async {
      repository.createDepartmentError = dioError(message: '중복된 부서명입니다.');

      final vm = build();

      expect(await vm.submitDepartment(null, '경영지원부'), '중복된 부서명입니다.');
    });

    test('deleteDepartment - 성공 시 null, 실패 시 메시지를 돌려준다', () async {
      final vm = build();

      expect(await vm.deleteDepartment(dept()), isNull);
      expect(repository.deletedDepartmentIds, [2]);

      repository.deleteDepartmentError =
          dioError(message: '소속 팀이 있어 삭제할 수 없습니다.');
      expect(await vm.deleteDepartment(dept()), '소속 팀이 있어 삭제할 수 없습니다.');

      repository.deleteDepartmentError = Exception('500');
      expect(await vm.deleteDepartment(dept()), '부서 삭제에 실패했습니다.');
    });
  });

  group('DepartmentTeamViewModel - 팀 저장/삭제', () {
    test('submitTeamCreate - 입력값을 요청 객체로 옮겨 전달한다', () async {
      final vm = build();

      expect(
        await vm.submitTeamCreate(
          teamName: '신규팀',
          managerId: 5,
          departmentId: 2,
          parentTeamId: 1,
        ),
        isNull,
      );

      final request = repository.createdTeams.single;
      expect(request.teamName, '신규팀');
      expect(request.projectManagerId, 5);
      expect(request.departmentId, 2);
      expect(request.parentTeamId, 1);
    });

    test('submitTeamCreate 실패 - 서버 메시지 또는 기본 문구를 돌려준다', () async {
      repository.createTeamError = dioError(message: '중복된 팀명입니다.');
      final vm = build();

      expect(
        await vm.submitTeamCreate(
            teamName: '신규팀', managerId: 5, departmentId: 2),
        '중복된 팀명입니다.',
      );

      repository.createTeamError = Exception('500');
      expect(
        await vm.submitTeamCreate(
            teamName: '신규팀', managerId: 5, departmentId: 2),
        '팀 등록에 실패했습니다.',
      );
    });

    test('submitTeamUpdate - 바뀐 값이 하나도 없으면 API를 부르지 않고 끝낸다', () async {
      final origin = team();
      final vm = build();

      final result = await vm.submitTeamUpdate(
        origin,
        teamName: origin.teamName,
        departmentId: origin.departmentId,
        parentTeamId: origin.parentTeamId,
      );

      expect(result, isNull);
      expect(repository.updatedTeams, isEmpty);
    });

    test('submitTeamUpdate - 바뀐 필드만 요청에 담는다', () async {
      final origin = team();
      final vm = build();

      expect(
        await vm.submitTeamUpdate(
          origin,
          teamName: '이름변경팀',
          departmentId: origin.departmentId,
          parentTeamId: origin.parentTeamId,
        ),
        isNull,
      );

      final entry = repository.updatedTeams.single;
      expect(entry['id'], 3);
      final request = entry['request'] as TeamUpdateRequest;
      expect(request.teamName, '이름변경팀');
      expect(request.departmentId, isNull);
      expect(request.parentTeamId, isNull);
      expect(request.projectManagerId, isNull);
      expect(request.toJson(), {'teamName': '이름변경팀'});
    });

    test('submitTeamUpdate - 담당자만 바꿔도 요청을 보낸다', () async {
      final origin = team();
      final vm = build();

      expect(
        await vm.submitTeamUpdate(
          origin,
          teamName: origin.teamName,
          departmentId: origin.departmentId,
          managerId: 9,
        ),
        isNull,
      );

      final request =
          repository.updatedTeams.single['request'] as TeamUpdateRequest;
      expect(request.projectManagerId, 9);
      expect(request.teamName, isNull);
    });

    test('submitTeamUpdate 실패 - 서버 메시지 또는 기본 문구를 돌려준다', () async {
      final origin = team();
      repository.updateTeamError = dioError(message: '상위 팀 순환 참조입니다.');
      final vm = build();

      expect(
        await vm.submitTeamUpdate(origin, teamName: '이름변경팀'),
        '상위 팀 순환 참조입니다.',
      );

      repository.updateTeamError = Exception('500');
      expect(
        await vm.submitTeamUpdate(origin, teamName: '이름변경팀2'),
        '팀 수정에 실패했습니다.',
      );
    });

    test('deleteTeam - 성공 시 null, 실패 시 메시지를 돌려준다', () async {
      final vm = build();

      expect(await vm.deleteTeam(team()), isNull);
      expect(repository.deletedTeamIds, [3]);

      repository.deleteTeamError = Exception('500');
      expect(await vm.deleteTeam(team()), '팀 삭제에 실패했습니다.');
    });
  });

  group('DepartmentTeamViewModel - 사원 검색', () {
    test('searchEmployees - 검색어를 그대로 저장소에 넘긴다', () async {
      repository.employeesToReturn = [
        Employee.fromJson(fixtureJson('admin/employee.json')),
      ];

      final vm = build();
      final result = await vm.searchEmployees('홍길동');

      expect(result, hasLength(1));
      expect(repository.employeeSearches, ['홍길동']);
    });
  });
}
