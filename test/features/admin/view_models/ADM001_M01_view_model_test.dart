import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM001_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

void main() {
  late FakeAdminEmployeeRepository repository;
  late FakeCommonCodeRepository commonCodes;

  Employee emp({
    String employeeNumber = 'A0001',
    String name = '홍길동',
    String position = '과장',
    String role = 'EMPLOYEE',
    List<String> teamList = const ['SI사업팀'],
  }) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['employeeNumber'] = employeeNumber
        ..['name'] = name
        ..['position'] = position
        ..['role'] = role
        ..['teamList'] = teamList);

  setUp(() {
    repository = FakeAdminEmployeeRepository();
    commonCodes = FakeCommonCodeRepository();
  });

  AdminSettingsViewModel build() => AdminSettingsViewModel(
        repository: repository,
        commonCodeRepository: commonCodes,
      );

  /// fetchEmployees 가 팀 조회를 await 없이 띄우므로 이벤트 루프를 한 바퀴 돌린다.
  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  group('AdminSettingsViewModel - 사원 목록', () {
    test('fetchEmployees - 첫 사원을 자동 선택하고 팀 분리까지 이어서 수행한다', () async {
      repository.employeesToReturn = [
        emp(role: 'ADMIN', teamList: const ['SI사업팀']),
        emp(employeeNumber: 'A0002', name: '김철수'),
      ];
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀', '인프라팀'],
      };

      final vm = build();
      await vm.fetchEmployees();
      await settle();

      expect(vm.employees, hasLength(2));
      expect(vm.selectedEmployee?.employeeNumber, 'A0001');
      expect(vm.managedTeams, ['SI사업팀']);
      expect(vm.generalTeams, ['BI사업팀', '인프라팀']);
      expect(vm.isLoading, isFalse);
    });

    test('fetchEmployees - 목록이 비면 선택 사원도 없고 팀 조회도 하지 않는다', () async {
      repository.employeesToReturn = [];

      final vm = build();
      await vm.fetchEmployees();
      await settle();

      expect(vm.employees, isEmpty);
      expect(vm.selectedEmployee, isNull);
      expect(commonCodes.fetchCount, 0);
      expect(vm.isLoading, isFalse);
    });

    test('fetchEmployees - 실패해도 로딩을 끄고 목록을 비운 채 유지한다', () async {
      repository.errorToThrow = Exception('403');

      final vm = build();
      await vm.fetchEmployees();
      await settle();

      expect(vm.employees, isEmpty);
      expect(vm.selectedEmployee, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('selectEmployee - 검색 입력란을 "이름 직급 사번" 형식으로 채운다', () async {
      final vm = build();

      vm.selectEmployee(
          emp(name: '김철수', position: '대리', employeeNumber: 'A0002'));
      await settle();

      expect(vm.employeeInfoController.text, '김철수 대리 A0002');
      expect(vm.selectedEmployee?.employeeNumber, 'A0002');
    });

    test('selectEmployeeByName - 이름이 일치하면 인덱스를, 없으면 -1을 돌려준다', () async {
      repository.employeesToReturn = [
        emp(),
        emp(employeeNumber: 'A0002', name: '김철수'),
      ];

      final vm = build();
      await vm.fetchEmployees();
      await settle();

      expect(vm.selectEmployeeByName('  김철수  '), 1);
      expect(vm.selectedEmployee?.employeeNumber, 'A0002');

      expect(vm.selectEmployeeByName('없는사람'), -1);
      // 실패해도 이전 선택은 그대로 유지된다.
      expect(vm.selectedEmployee?.employeeNumber, 'A0002');
      await settle();
    });
  });

  group('AdminSettingsViewModel - 팀 분리 매핑', () {
    test('동명이인 팀 중복 방어 - 같은 이름이 반복되면 두 번째부터 "(n)"을 붙인다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'SI사업팀', 'BI사업팀', 'SI사업팀'],
      };

      final vm = build();
      vm.selectEmployee(emp(role: 'EMPLOYEE'));
      await vm.fetchEmployeeTeams();

      expect(vm.generalTeams, ['SI사업팀', 'SI사업팀 (2)', 'BI사업팀', 'SI사업팀 (3)']);
      expect(vm.managedTeams, isEmpty);
    });

    test('startsWith 매칭 - 관리자의 팀 이름과 넘버링된 동명 팀을 모두 관리팀으로 넣는다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'SI사업팀', 'BI사업팀', 'SI사업팀'],
      };

      final vm = build();
      vm.selectEmployee(emp(role: 'ADMIN', teamList: const ['SI사업팀']));
      await vm.fetchEmployeeTeams();

      expect(vm.managedTeams, ['SI사업팀', 'SI사업팀 (2)', 'SI사업팀 (3)']);
      expect(vm.generalTeams, ['BI사업팀']);
    });

    test('EMPLOYEE 역할이면 소속 팀이 있어도 관리팀이 비어 있다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };

      final vm = build();
      vm.selectEmployee(emp(role: 'EMPLOYEE', teamList: const ['SI사업팀']));
      await vm.fetchEmployeeTeams();

      expect(vm.managedTeams, isEmpty);
      expect(vm.generalTeams, ['SI사업팀', 'BI사업팀']);
    });

    test('MANAGER 역할도 관리자로 취급한다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };

      final vm = build();
      vm.selectEmployee(emp(role: 'manager', teamList: const ['BI사업팀']));
      await vm.fetchEmployeeTeams();

      expect(vm.managedTeams, ['BI사업팀']);
      expect(vm.generalTeams, ['SI사업팀']);
    });

    test('accessibleTeam이 없으면 team 키를 대신 쓴다', () async {
      commonCodes.codesToReturn = {
        'team': ['총무팀'],
      };

      final vm = build();
      vm.selectEmployee(emp(role: 'EMPLOYEE'));
      await vm.fetchEmployeeTeams();

      expect(vm.generalTeams, ['총무팀']);
    });

    test('선택된 사원이 없으면 조회하지 않는다', () async {
      final vm = build();

      await vm.fetchEmployeeTeams();

      expect(commonCodes.fetchCount, 0);
      expect(vm.generalTeams, isEmpty);
    });

    test('기초 코드 조회가 실패하면 목록을 건드리지 않는다', () async {
      commonCodes.errorToThrow = Exception('500');

      final vm = build();
      vm.selectEmployee(emp());
      await vm.fetchEmployeeTeams();

      expect(vm.generalTeams, isEmpty);
      expect(vm.managedTeams, isEmpty);
    });
  });

  group('AdminSettingsViewModel - 팀 이동', () {
    Future<AdminSettingsViewModel> loaded({String role = 'EMPLOYEE'}) async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };
      final vm = build();
      vm.selectEmployee(emp(role: role, teamList: const ['SI사업팀']));
      await vm.fetchEmployeeTeams();
      return vm;
    }

    test('일반팀과 관리팀 선택은 서로 배타적이다', () async {
      final vm = await loaded();

      vm.selectGeneralTeam('SI사업팀');
      expect(vm.selectedGeneralTeam, 'SI사업팀');
      expect(vm.selectedManagedTeam, isNull);

      vm.selectManagedTeam('BI사업팀');
      expect(vm.selectedManagedTeam, 'BI사업팀');
      expect(vm.selectedGeneralTeam, isNull);
    });

    test('moveToAdmin - 선택한 일반팀을 관리팀으로 옮기고 선택을 해제한다', () async {
      final vm = await loaded();

      vm.selectGeneralTeam('SI사업팀');
      vm.moveToAdmin();

      expect(vm.generalTeams, ['BI사업팀']);
      expect(vm.managedTeams, ['SI사업팀']);
      expect(vm.selectedGeneralTeam, isNull);
    });

    test('moveToGeneral - 선택한 관리팀을 일반팀으로 되돌린다', () async {
      final vm = await loaded(role: 'ADMIN');
      expect(vm.managedTeams, ['SI사업팀']);

      vm.selectManagedTeam('SI사업팀');
      vm.moveToGeneral();

      expect(vm.managedTeams, isEmpty);
      expect(vm.generalTeams, ['BI사업팀', 'SI사업팀']);
      expect(vm.selectedManagedTeam, isNull);
    });

    test('선택된 팀이 없으면 이동 버튼이 아무 일도 하지 않는다', () async {
      final vm = await loaded();

      vm.moveToAdmin();
      vm.moveToGeneral();

      expect(vm.generalTeams, ['SI사업팀', 'BI사업팀']);
      expect(vm.managedTeams, isEmpty);
    });

    test('toggleChangedTeam - 같은 팀을 왕복시키면 저장 대상에서 빠진다', () async {
      final vm = await loaded();

      vm.selectGeneralTeam('SI사업팀');
      vm.moveToAdmin(); // 변경 목록에 추가
      vm.selectManagedTeam('SI사업팀');
      vm.moveToGeneral(); // 같은 팀이므로 변경 목록에서 제거

      await vm.saveChanges();
      await settle();

      expect(repository.updates.single.data['targetTeamsForRoleSwap'], isEmpty);
    });
  });

  group('AdminSettingsViewModel - 저장', () {
    test('saveChanges - 사원 정보와 변경 팀 목록을 함께 전송한다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };
      final vm = build();
      vm.selectEmployee(emp());
      await vm.fetchEmployeeTeams();

      vm.selectGeneralTeam('BI사업팀');
      vm.moveToAdmin();

      expect(await vm.saveChanges(), isNull);
      await settle();

      final update = repository.updates.single;
      expect(update.employeeNumber, 'A0001');
      expect(update.data['name'], '홍길동');
      expect(update.data['email'], 'hong@example.com');
      expect(update.data['department'], '경영지원부');
      expect(update.data['team'], 'SI사업팀');
      expect(update.data['position'], '과장');
      expect(update.data['hireDate'], '2020-01-01');
      expect(update.data['targetTeamsForRoleSwap'], ['BI사업팀']);
      expect(vm.isLoading, isFalse);
    });

    test('saveChanges - 성공 상태코드면 목록을 다시 조회한다', () async {
      repository.employeesToReturn = [emp()];
      repository.updateStatusCodeToReturn = 204;

      final vm = build();
      vm.selectEmployee(emp());
      await settle();

      expect(await vm.saveChanges(), isNull);
      await settle();

      expect(repository.fetchQueries, hasLength(1));
    });

    test('saveChanges - 실패 상태코드면 재조회하지 않는다', () async {
      repository.updateStatusCodeToReturn = 400;

      final vm = build();
      vm.selectEmployee(emp());
      await settle();

      expect(await vm.saveChanges(), isNull);
      await settle();

      expect(repository.fetchQueries, isEmpty);
    });

    test('saveChanges - 예외가 나면 오류 메시지를 돌려주고 변경 목록을 비운다', () async {
      commonCodes.codesToReturn = {
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
      };
      repository.updateErrorToThrow = Exception('500');

      final vm = build();
      vm.selectEmployee(emp());
      await vm.fetchEmployeeTeams();
      vm.selectGeneralTeam('BI사업팀');
      vm.moveToAdmin();

      expect(await vm.saveChanges(), '저장 중 오류가 발생했습니다.');
      expect(vm.isLoading, isFalse);

      // 실패 후 다시 저장하면 변경 목록은 이미 비워져 있다.
      repository.updateErrorToThrow = null;
      await vm.saveChanges();
      await settle();

      expect(repository.updates.last.data['targetTeamsForRoleSwap'], isEmpty);
    });

    test('saveChanges - 선택된 사원이 없으면 아무 요청도 보내지 않는다', () async {
      final vm = build();

      expect(await vm.saveChanges(), isNull);
      expect(repository.updates, isEmpty);
    });
  });
}
