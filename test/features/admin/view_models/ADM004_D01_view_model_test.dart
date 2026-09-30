import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM004_D01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

void main() {
  late FakeAdminEmployeeRepository repository;
  late FakeCommonCodeRepository commonCodes;

  Employee emp({
    Object? hireDate = '2020-01-01',
    Object? fireDate,
    String role = 'EMPLOYEE',
    String team = 'SI사업팀',
  }) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['hireDate'] = hireDate
        ..['fireDate'] = fireDate
        ..['role'] = role
        ..['team'] = team);

  setUp(() {
    repository = FakeAdminEmployeeRepository();
    commonCodes = FakeCommonCodeRepository();
  });

  EmployeeDetailViewModel build(Employee employee) => EmployeeDetailViewModel(
        employee: employee,
        repository: repository,
        commonCodeRepository: commonCodes,
      );

  group('EmployeeDetailViewModel - 날짜 파싱 방어', () {
    test('ISO 날짜는 yyyy.MM.dd 표시로 바꾸고 DateTime으로도 보관한다', () {
      final vm = build(emp(hireDate: '2020-01-01', fireDate: '2024-12-31'));

      expect(vm.hireDateController.text, '2020.01.01');
      expect(vm.fireDateController.text, '2024.12.31');
      expect(vm.selectedHireDate, DateTime(2020, 1, 1));
      expect(vm.selectedFireDate, DateTime(2024, 12, 31));
    });

    test("'T'가 포함된 날짜시각 문자열은 날짜 부분만 잘라 쓴다", () {
      final vm = build(emp(
        hireDate: '2020-05-06T00:00:00',
        fireDate: '2024-07-08T13:45:00.000Z',
      ));

      expect(vm.hireDateController.text, '2020.05.06');
      expect(vm.fireDateController.text, '2024.07.08');
      expect(vm.selectedHireDate, DateTime(2020, 5, 6));
      expect(vm.selectedFireDate, DateTime(2024, 7, 8));
    });

    test('퇴사일이 null이면 입력란은 비고 선택 날짜도 null이다', () {
      final vm = build(emp(fireDate: null));

      expect(vm.fireDateController.text, isEmpty);
      expect(vm.selectedFireDate, isNull);
    });

    test('빈 문자열 날짜는 파싱 예외를 삼키고 null로 남긴다', () {
      final vm = build(emp(hireDate: '', fireDate: ''));

      expect(vm.hireDateController.text, isEmpty);
      expect(vm.fireDateController.text, isEmpty);
      expect(vm.selectedHireDate, isNull);
      expect(vm.selectedFireDate, isNull);
    });

    // 발견한 문제: 연도 4자리만 오면 "-01-01"을 붙이는 방어 로직이 아래쪽에 있지만,
    // 그보다 먼저 실행되는 표시용 컨트롤러 초기화가 try 밖에서 DateTime.parse 를
    // 호출하므로 생성 자체가 실패한다. 즉 4자리 보정 분기는 도달할 수 없다.
    test('연도 4자리만 오면 표시용 파싱에서 예외가 그대로 터진다 (현재 동작)', () {
      expect(() => build(emp(hireDate: '2020')), throwsFormatException);
      expect(() => build(emp(fireDate: '2024')), throwsFormatException);
    });

    test('날짜 형식이 아닌 문자열도 생성자에서 예외가 터진다 (현재 동작)', () {
      expect(() => build(emp(hireDate: '알수없음')), throwsFormatException);
    });

    test('생성자는 사원 정보를 그대로 입력 상태에 옮겨 담는다', () {
      final vm = build(emp());

      expect(vm.nameController.text, '홍길동');
      expect(vm.emailController.text, 'hong@example.com');
      expect(vm.selectedDepartment, '경영지원부');
      expect(vm.selectedTeam, 'SI사업팀');
      expect(vm.selectedPosition, '과장');
      expect(vm.isEditing, isFalse);
      expect(vm.isLoadingCommon, isTrue);
    });
  });

  group('EmployeeDetailViewModel - 기초 코드 조회', () {
    test('문자열과 맵이 섞인 팀 응답에서 이름만 뽑아낸다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'department': ['경영지원부', '기술본부'],
        'position': ['사원', '과장'],
        'team': [
          'SI사업팀',
          {'teamName': 'BI사업팀'},
          {'name': '인프라팀'},
          {'noNameKey': 1},
        ],
      };

      final vm = build(emp());
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀', 'BI사업팀', '인프라팀']);
      expect(vm.departmentList, ['경영지원부', '기술본부']);
      expect(vm.positionList, ['사원', '과장']);
      expect(vm.isLoadingCommon, isFalse);
    });

    test('accessibleTeam이 있으면 team보다 우선한다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀'],
        'team': ['쓰이지않는팀'],
        'position': <String>[],
        'department': <String>[],
      };

      final vm = build(emp());
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀']);
    });

    test('원 소속팀이 목록에 없으면 목록 끝에 덧붙이고 선택 상태로 둔다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀'],
        'position': <String>[],
        'department': <String>[],
      };

      final vm = build(emp(team: '폐지예정팀'));
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀', '폐지예정팀']);
      expect(vm.selectedTeam, '폐지예정팀');
    });

    test('원 소속팀이 이미 목록에 있으면 덧붙이지 않는다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
        'position': <String>[],
        'department': <String>[],
      };

      final vm = build(emp(team: 'SI사업팀'));
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀', 'BI사업팀']);
      expect(vm.selectedTeam, 'SI사업팀');
    });

    test('원 소속팀이 빈 문자열이면 아무것도 덧붙이지 않는다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀'],
        'position': <String>[],
        'department': <String>[],
      };

      final vm = build(emp(team: ''));
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀']);
      // 선택 상태는 생성자에서 넣은 빈 문자열 그대로 남는다. (현재 동작)
      expect(vm.selectedTeam, '');
    });

    test('두 번 호출해도 목록이 중복해서 쌓이지 않는다', () async {
      commonCodes.codesToReturn = <String, dynamic>{
        'accessibleTeam': ['SI사업팀', 'BI사업팀'],
        'position': ['과장'],
        'department': ['경영지원부'],
      };

      final vm = build(emp());
      await vm.fetchCommonData();
      await vm.fetchCommonData();

      expect(vm.teamList, ['SI사업팀', 'BI사업팀']);
      expect(vm.positionList, ['과장']);
      expect(commonCodes.fetchCount, 2);
    });

    test('조회에 실패해도 로딩만 끄고 목록은 비운 채 유지한다', () async {
      commonCodes.errorToThrow = Exception('500');

      final vm = build(emp());
      await vm.fetchCommonData();

      expect(vm.teamList, isEmpty);
      expect(vm.departmentList, isEmpty);
      expect(vm.isLoadingCommon, isFalse);
    });
  });

  group('EmployeeDetailViewModel - 저장', () {
    test('점으로 구분한 날짜를 하이픈으로 바꿔 전송한다', () async {
      final vm = build(emp(hireDate: '2020-01-01', fireDate: '2024-12-31'));

      expect(await vm.saveChanges(), isTrue);

      final data = repository.updates.single.data;
      expect(data['hireDate'], '2020-01-01');
      expect(data['fireDate'], '2024-12-31');
      expect(data['firedDate'], '2024-12-31');
    });

    test('날짜가 10자리가 아니면 null로 보낸다', () async {
      final vm = build(emp(fireDate: null));
      vm.hireDateController.text = '2020.01';

      expect(await vm.saveChanges(), isTrue);

      final data = repository.updates.single.data;
      expect(data['hireDate'], isNull);
      expect(data['fireDate'], isNull);
      expect(data['firedDate'], isNull);
    });

    test('저장 요청에 역할 관련 값을 담지 않는다', () async {
      // 이 화면에는 역할을 바꾸는 입력이 없다. 역할 지정은 ADM001_M01에서만 한다.
      // 서버의 targetTeamsForRoleSwap은 받은 팀을 토글하므로, 이 화면이 현재 팀을
      // 계속 보내면 저장할 때마다 관리자 등록과 해제가 번갈아 일어난다.
      final vm = build(emp(role: 'ADMIN'));
      vm.nameController.text = '  홍길동  ';
      vm.emailController.text = '  hong@example.com  ';

      expect(await vm.saveChanges(), isTrue);

      final update = repository.updates.single;
      expect(update.employeeNumber, 'A0001');
      expect(update.data['name'], '홍길동');
      expect(update.data['email'], 'hong@example.com');
      expect(update.data['team'], 'SI사업팀');
      expect(update.data['currTotalLeaveDays'], 15.0);
      expect(update.data.containsKey('role'), isFalse);
      expect(update.data.containsKey('targetTeamForRoleSwap'), isFalse);
      expect(update.data.containsKey('targetTeamsForRoleSwap'), isFalse);
    });

    test('멤버인 사원을 저장해도 역할 관련 값이 없다', () async {
      final vm = build(emp(role: 'EMPLOYEE'));

      expect(await vm.saveChanges(), isTrue);

      final data = repository.updates.single.data;
      expect(data.containsKey('role'), isFalse);
      expect(data.containsKey('targetTeamForRoleSwap'), isFalse);
      expect(data.containsKey('targetTeamsForRoleSwap'), isFalse);
    });

    test('비밀번호를 입력했을 때만 password 필드를 채운다', () async {
      final vm = build(emp());
      vm.passwordController.text = '  newPw1234  ';

      expect(await vm.saveChanges(), isTrue);

      expect(repository.updates.single.data['password'], 'newPw1234');
      // 저장 성공 후 비밀번호 입력란은 비워진다.
      expect(vm.passwordController.text, isEmpty);
    });

    test('성공 상태코드면 수정 모드를 끄고 true를 돌려준다', () async {
      repository.updateStatusCodeToReturn = 204;

      final vm = build(emp());
      vm.setEditing(true);

      expect(await vm.saveChanges(), isTrue);
      expect(vm.isEditing, isFalse);
      expect(vm.isSaving, isFalse);
    });

    test('성공이 아닌 상태코드면 수정 모드를 유지하고 false를 돌려준다', () async {
      repository.updateStatusCodeToReturn = 400;

      final vm = build(emp());
      vm.setEditing(true);

      expect(await vm.saveChanges(), isFalse);
      expect(vm.isEditing, isTrue);
      expect(vm.isSaving, isFalse);
    });

    test('예외가 나면 false를 돌려주고 저장 상태를 되돌린다', () async {
      repository.updateErrorToThrow = Exception('500');

      final vm = build(emp());
      vm.setEditing(true);

      expect(await vm.saveChanges(), isFalse);
      expect(vm.isEditing, isTrue);
      expect(vm.isSaving, isFalse);
    });
  });

  group('EmployeeDetailViewModel - 선택 상태', () {
    test('선택 메서드는 값을 바꾸고 리스너에 알린다', () {
      final vm = build(emp());
      var notified = 0;
      vm.addListener(() => notified++);

      vm.setEditing(true);
      vm.selectDepartment('기술본부');
      vm.selectTeam('BI사업팀');
      vm.selectPosition('부장');

      expect(vm.isEditing, isTrue);
      expect(vm.selectedDepartment, '기술본부');
      expect(vm.selectedTeam, 'BI사업팀');
      expect(vm.selectedPosition, '부장');
      expect(notified, 4);
    });
  });
}
