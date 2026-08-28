import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM004_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

void main() {
  late FakeAdminEmployeeRepository repository;
  late FakeCommonCodeRepository commonCodes;

  Employee emp({
    required String employeeNumber,
    String name = '홍길동',
    String team = 'SI사업팀',
    bool isRegisted = true,
  }) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['employeeNumber'] = employeeNumber
        ..['name'] = name
        ..['team'] = team
        ..['isRegisted'] = isRegisted);

  setUp(() {
    repository = FakeAdminEmployeeRepository();
    commonCodes = FakeCommonCodeRepository();
  });

  SearchEmployeeNumberViewModel build() => SearchEmployeeNumberViewModel(
        repository: repository,
        commonCodeRepository: commonCodes,
      );

  /// setStatus / setTeamFilter 가 fetch 를 await 없이 띄우므로 루프를 돌린다.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('SearchEmployeeNumberViewModel - 팀 필터 목록', () {
    test('검색어가 없으면 조회 결과의 팀을 중복 제거하고 가나다순으로 담는다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: '인프라팀'),
        emp(employeeNumber: 'A0002', team: 'SI사업팀'),
        emp(employeeNumber: 'A0003', team: 'BI사업팀'),
        emp(employeeNumber: 'A0004', team: 'SI사업팀'),
        emp(employeeNumber: 'A0005', team: '  '),
      ];

      final vm = build();
      await vm.fetch();

      expect(vm.filterTeamList, ['전체', 'BI사업팀', 'SI사업팀', '인프라팀']);
      expect(repository.fetchQueries, ['']);
      expect(vm.isLoading, isFalse);
    });

    test('검색어가 있으면 팀 필터 목록을 다시 만들지 않는다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: '인프라팀'),
      ];

      final vm = build();
      vm.searchParamController.text = '  홍길동  ';
      await vm.fetch();

      expect(vm.filterTeamList, ['전체']);
      expect(repository.fetchQueries, ['홍길동']);
      expect(vm.items, hasLength(1));
    });

    test('fetchCommonTeams - 기초 코드의 팀 목록으로 필터를 채운다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };

      final vm = build();
      await vm.fetchCommonTeams();

      expect(vm.filterTeamList, ['전체', 'SI사업팀', 'BI사업팀']);
    });

    test('fetchCommonTeams - accessibleTeam이 없으면 team 키를 쓴다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'team': ['총무팀'],
      };

      final vm = build();
      await vm.fetchCommonTeams();

      expect(vm.filterTeamList, ['전체', '총무팀']);
    });

    test('fetchCommonTeams - 실패하면 기존 목록을 그대로 둔다', () async {
      commonCodes.errorToThrow = Exception('500');

      final vm = build();
      await vm.fetchCommonTeams();

      expect(vm.filterTeamList, ['전체']);
    });
  });

  group('SearchEmployeeNumberViewModel - 검색 조건', () {
    test('팀 필터 - 선택한 팀 이름이 포함된 사원만 남긴다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: 'SI사업팀'),
        emp(employeeNumber: 'A0002', team: 'BI사업팀'),
      ];

      final vm = build();
      vm.setTeamFilter('SI사업팀');
      await settle();

      expect(vm.selectedTeamFilter, 'SI사업팀');
      expect(vm.items.map((e) => e.employeeNumber), ['A0001']);
    });

    test('팀 필터 - 공백과 " 팀" 표기를 무시하고 비교한다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: 'SI 사업팀'),
        emp(employeeNumber: 'A0002', team: 'BI사업팀'),
      ];

      final vm = build();
      vm.setTeamFilter('SI사업 팀');
      await settle();

      expect(vm.items.map((e) => e.employeeNumber), ['A0001']);
    });

    test('팀 필터가 전체면 아무도 걸러내지 않는다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: 'SI사업팀'),
        emp(employeeNumber: 'A0002', team: 'BI사업팀'),
      ];

      final vm = build();
      await vm.fetch();

      expect(vm.selectedTeamFilter, '전체');
      expect(vm.items, hasLength(2));
    });

    test('상태 필터 ALL - 등록 여부와 무관하게 모두 보여준다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', isRegisted: true),
        emp(employeeNumber: 'A0002', isRegisted: false),
      ];

      final vm = build();
      await vm.fetch();

      expect(vm.selectedStatus, 'ALL');
      expect(vm.items, hasLength(2));
    });

    test('상태 필터 REGISTERED - 사용 등록된 사원만 남긴다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', isRegisted: true),
        emp(employeeNumber: 'A0002', isRegisted: false),
      ];

      final vm = build();
      vm.setStatus('REGISTERED');
      await settle();

      expect(vm.items.map((e) => e.employeeNumber), ['A0001']);
    });

    test('상태 필터 UNREGISTERED - 미등록 사원만 남긴다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', isRegisted: true),
        emp(employeeNumber: 'A0002', isRegisted: false),
      ];

      final vm = build();
      vm.setStatus('UNREGISTERED');
      await settle();

      expect(vm.items.map((e) => e.employeeNumber), ['A0002']);
    });

    test('팀 필터와 상태 필터는 함께 적용된다', () async {
      repository.employeesToReturn = [
        emp(employeeNumber: 'A0001', team: 'SI사업팀', isRegisted: true),
        emp(employeeNumber: 'A0002', team: 'SI사업팀', isRegisted: false),
        emp(employeeNumber: 'A0003', team: 'BI사업팀', isRegisted: false),
      ];

      final vm = build();
      vm.setTeamFilter('SI사업팀');
      await settle();
      vm.setStatus('UNREGISTERED');
      await settle();

      expect(vm.items.map((e) => e.employeeNumber), ['A0002']);
    });

    test('setStatus / setTeamFilter 는 조건을 바꾸고 즉시 재조회한다', () async {
      final vm = build();
      await vm.fetch();
      expect(repository.fetchQueries, hasLength(1));

      vm.setStatus('REGISTERED');
      await settle();
      vm.setTeamFilter('SI사업팀');
      await settle();

      expect(repository.fetchQueries, hasLength(3));
    });
  });

  group('SearchEmployeeNumberViewModel - 실패 처리', () {
    test('조회에 실패해도 로딩을 끄고 기존 목록을 유지한다', () async {
      repository.employeesToReturn = [emp(employeeNumber: 'A0001')];

      final vm = build();
      await vm.fetch();
      expect(vm.items, hasLength(1));

      repository.errorToThrow = Exception('500');
      await vm.fetch();

      expect(vm.items, hasLength(1));
      expect(vm.isLoading, isFalse);
    });
  });
}
