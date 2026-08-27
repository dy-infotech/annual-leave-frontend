import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM003_M01.dart';
import 'package:annual_leave_frontend/features/admin/repositories/department_team_repository.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 부서 및 팀 관리 화면 테스트.
///
/// DepartmentTeamRepository 를 인메모리 페이크로 주입해 서버 없이
/// 조회·추가·수정·삭제 흐름과 보호 규칙(대표이사 부서, 루트 팀)을 검증한다.
void main() {
  late _FakeDepartmentTeamApi fake;

  setUp(() {
    fake = _FakeDepartmentTeamApi();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: DepartmentTeamManageScreen(repository: fake),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('대표이사').evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> goToTeamTab(WidgetTester tester) async {
    await tester.tap(find.byType(Tab).last);
    await settle(tester);
  }

  group('부서 탭', () {
    testWidgets('조회 — 부서 목록과 소속 팀 정보가 표시된다', (tester) async {
      await pumpScreen(tester);

      expect(find.text('부서 및 팀 관리'), findsOneWidget);
      // 시드 부서 3건 + 탭에 건수 표기
      expect(find.text('부서 3'), findsOneWidget);
      expect(find.text('대표이사'), findsWidgets);
      expect(find.text('SI사업팀'), findsOneWidget);
      expect(find.text('경영지원부'), findsOneWidget);
      // 소속 팀 수와 팀 이름 칩이 카드에 바로 노출된다
      expect(find.text('소속 팀 1개'), findsNWidgets(2));
      expect(find.text('소속 팀 없음'), findsOneWidget);
      expect(find.text('스마트팩토리구축사업'), findsOneWidget);
    });

    testWidgets('대표이사 부서 — 수정·삭제 메뉴 대신 잠금 아이콘이 표시된다', (tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // 메뉴는 나머지 두 부서에만 노출된다 (부서 탭에는 팀 카드가 없다)
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });

    testWidgets('추가 — 시트에서 등록하면 목록에 반영된다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('부서 추가'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, '신규사업부');
      await tester.tap(find.text('등록'));
      await settle(tester);

      expect(find.text('신규사업부'), findsOneWidget);
      expect(fake.departments.any((d) => d.departmentName == '신규사업부'), isTrue);
    });

    testWidgets('추가 — 중복 이름이면 시트가 닫히지 않고 서버 메시지를 보여준다', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('부서 추가'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, 'SI사업팀');
      await tester.tap(find.text('등록'));
      await settle(tester);

      expect(find.text('이미 존재하는 부서명입니다.'), findsOneWidget);
      expect(find.text('등록'), findsOneWidget); // 시트가 열려 있다
    });

    testWidgets('이름 변경 — 카드 메뉴에서 수정하면 반영된다', (tester) async {
      await pumpScreen(tester);

      // 첫 번째 메뉴 = SI사업팀 (대표이사 부서는 메뉴가 없다)
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await settle(tester);
      await tester.tap(find.text('이름 변경'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, 'SI사업본부');
      await tester.tap(find.text('저장'));
      await settle(tester);

      expect(find.text('SI사업본부'), findsOneWidget);
      expect(find.text('SI사업팀'), findsNothing);
    });

    testWidgets('삭제 — 확인 다이얼로그를 거쳐 목록에서 제거된다', (tester) async {
      await pumpScreen(tester);

      // 두 번째 메뉴 = 경영지원부 (소속 팀 없음)
      await tester.tap(find.byIcon(Icons.more_vert).at(1));
      await settle(tester);
      await tester.tap(find.text('삭제'));
      await settle(tester);

      expect(find.text('부서 삭제'), findsOneWidget);
      await tester.tap(find.text('삭제').last);
      await settle(tester);

      expect(find.text('경영지원부'), findsNothing);
      expect(fake.departments.any((d) => d.departmentName == '경영지원부'), isFalse);
    });
  });

  group('팀 탭', () {
    testWidgets('조회 — 소속 부서·담당자·상위 팀이 카드에 표시된다', (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      expect(find.text('스마트팩토리구축사업'), findsWidgets);
      expect(find.text('담당자'), findsWidgets);
      expect(find.text('이호영 이사 (A2020001)'), findsOneWidget);
      expect(find.text('상위 팀'), findsOneWidget);
      // 루트 팀 배지
      expect(find.text('최상위'), findsOneWidget);
    });

    testWidgets('부서 필터 — 칩을 선택하면 해당 부서 팀만 보인다', (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      // 'SI사업팀 1' 필터 칩 선택
      await tester.tap(find.text('SI사업팀 1'));
      await settle(tester);

      expect(find.text('스마트팩토리구축사업'), findsOneWidget);
      expect(find.text('최상위'), findsNothing); // 대표이사 팀이 걸러졌다

      // 팀이 없는 부서를 선택하면 안내 문구가 보인다
      await tester.tap(find.text('경영지원부 0'));
      await settle(tester);
      expect(find.text('이 부서에 소속된 팀이 없습니다.'), findsOneWidget);
    });

    testWidgets('추가 — 담당자를 지정하지 않으면 저장되지 않는다', (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      await tester.tap(find.text('팀 추가'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, '신규팀');
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await settle(tester);
      await tester.tap(find.text('SI사업팀').last);
      await settle(tester);

      await tester.tap(find.text('등록'));
      await settle(tester);

      expect(find.text('팀 담당자를 지정해 주세요.'), findsOneWidget);
    });

    testWidgets('추가 — 사원을 조회해 담당자를 지정하면 등록된다', (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      await tester.tap(find.text('팀 추가'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).last, '품질관리팀');
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await settle(tester);
      await tester.tap(find.text('SI사업팀').last);
      await settle(tester);

      // 담당자 선택 다이얼로그를 열어 한 명 선택
      await tester.tap(find.text('선택'));
      await settle(tester);
      expect(find.text('팀 담당자 선택'), findsOneWidget);
      await tester.tap(find.textContaining('김도현').first);
      await settle(tester);

      expect(find.text('김도현 과장'), findsOneWidget);

      await tester.tap(find.text('등록'));
      await settle(tester);

      expect(find.text('품질관리팀'), findsWidgets);
      final saved =
          fake.teams.firstWhere((t) => t.teamName == '품질관리팀');
      expect(saved.managers.single.name, '김도현');
      expect(saved.departmentName, 'SI사업팀');
      // 상위 팀 미지정 → 대표이사 팀 직속
      expect(saved.parentTeamName, '대표이사');
    });

    testWidgets('수정 — 변경 전에는 저장이 비활성화되고, 팀명 변경 시 상위 팀이 유지된다',
        (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      // 두 번째 메뉴 = 스마트팩토리구축사업 (첫 번째는 루트 팀)
      await tester.tap(find.byIcon(Icons.more_vert).at(1));
      await settle(tester);
      await tester.tap(find.text('팀 수정'));
      await settle(tester);

      // 변경 사항이 없으면 저장 버튼이 비활성화된다
      final saveButton =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, '스마트팩토리사업부');
      await settle(tester);
      await tester.tap(find.text('저장'));
      await settle(tester);

      expect(find.text('스마트팩토리사업부'), findsWidgets);
      final updated =
          fake.teams.firstWhere((t) => t.teamName == '스마트팩토리사업부');
      // 보내지 않은 필드(상위 팀·부서·담당자)는 유지된다
      expect(updated.parentTeamName, '대표이사');
      expect(updated.departmentName, 'SI사업팀');
      expect(updated.managers.single.name, '이호영');
    });

    testWidgets('루트 팀 — 삭제 메뉴가 노출되지 않는다', (tester) async {
      await pumpScreen(tester);
      await goToTeamTab(tester);

      // 첫 번째 메뉴 = 대표이사(루트) 팀
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await settle(tester);

      expect(find.text('팀 수정'), findsOneWidget);
      expect(find.text('삭제'), findsNothing);
    });
  });
}

// ------------------------------------------------------------------ 페이크 API

/// 인메모리 페이크. 백엔드 시드 데이터(sql/data.sql)와 제약을 흉내 낸다.
class _FakeDepartmentTeamApi extends DepartmentTeamRepository {
  final List<Department> departments = [];
  final List<Team> teams = [];
  final List<Employee> employees = [];

  int _deptSeq = 0;
  int _teamSeq = 0;

  _FakeDepartmentTeamApi() {
    for (final name in const ['대표이사', 'SI사업팀', '경영지원부']) {
      departments
          .add(Department(departmentId: ++_deptSeq, departmentName: name));
    }

    employees.addAll([
      _employee(1, 'A2011001', '우동영', '사장'),
      _employee(4, 'A2020001', '이호영', '이사'),
      _employee(5, 'A2022004', '김도현', '과장'),
      _employee(6, 'A2025015', '이서우', '사원'),
    ]);

    // 루트 팀은 상위 팀이 자기 자신이다(백엔드 시드와 동일).
    teams.add(Team(
      teamId: ++_teamSeq,
      teamName: '대표이사',
      departmentId: 1,
      departmentName: '대표이사',
      parentTeamId: 1,
      parentTeamName: '대표이사',
      managers: [_manager('A2011001')],
    ));
    teams.add(Team(
      teamId: ++_teamSeq,
      teamName: '스마트팩토리구축사업',
      departmentId: 2,
      departmentName: 'SI사업팀',
      parentTeamId: 1,
      parentTeamName: '대표이사',
      managers: [_manager('A2020001')],
    ));
  }

  static Employee _employee(
      int id, String number, String name, String position) {
    return Employee(
      employeeId: id,
      employeeNumber: number,
      name: name,
      position: position,
      department: 'SI사업팀',
      team: '스마트팩토리구축사업',
      teamList: null,
      currTotalLeaveDays: 15,
      remainingLeaveDays: 15,
      isRegisted: true,
    );
  }

  TeamManager _manager(String employeeNumber) {
    final e = employees.firstWhere((e) => e.employeeNumber == employeeNumber);
    return TeamManager(
      employeeId: e.employeeId!,
      employeeNumber: e.employeeNumber,
      name: e.name,
      position: e.position,
    );
  }

  /// 서버 에러 응답과 동일하게 message 를 담아 던진다.
  Never _reject(String message) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      message: message,
    );
  }

  Team _rebuild(
    Team origin, {
    String? teamName,
    int? departmentId,
    int? parentTeamId,
    List<TeamManager>? managers,
  }) {
    final deptId = departmentId ?? origin.departmentId;
    final parentId = parentTeamId ?? origin.parentTeamId;
    return Team(
      teamId: origin.teamId,
      teamName: teamName ?? origin.teamName,
      departmentId: deptId,
      departmentName: departments
          .firstWhere((d) => d.departmentId == deptId)
          .departmentName,
      parentTeamId: parentId,
      parentTeamName: parentId == null
          ? null
          : teams.firstWhere((t) => t.teamId == parentId).teamName,
      managers: managers ?? origin.managers,
    );
  }

  /// 팀명·부서명 변경이 다른 팀 카드의 표시값에도 반영되도록 전체를 다시 만든다.
  void _refreshDerivedNames() {
    for (var i = 0; i < teams.length; i++) {
      teams[i] = _rebuild(teams[i]);
    }
  }

  @override
  Future<List<Department>> fetchDepartments() async => List.of(departments);

  @override
  Future<void> createDepartment(String departmentName) async {
    if (departments.any((d) => d.departmentName == departmentName)) {
      _reject('이미 존재하는 부서명입니다.');
    }
    departments
        .add(Department(departmentId: ++_deptSeq, departmentName: departmentName));
  }

  @override
  Future<void> updateDepartment(int departmentId, String departmentName) async {
    if (departments.any((d) =>
        d.departmentName == departmentName && d.departmentId != departmentId)) {
      _reject('이미 존재하는 부서명입니다.');
    }
    final index =
        departments.indexWhere((d) => d.departmentId == departmentId);
    departments[index] = Department(
        departmentId: departmentId, departmentName: departmentName);
    _refreshDerivedNames();
  }

  @override
  Future<void> deleteDepartment(int departmentId) async {
    if (teams.any((t) => t.departmentId == departmentId)) {
      _reject('소속된 활성 팀이 있는 부서는 삭제할 수 없습니다. 팀을 먼저 정리해주세요.');
    }
    departments.removeWhere((d) => d.departmentId == departmentId);
  }

  @override
  Future<List<Team>> fetchTeams() async => List.of(teams);

  @override
  Future<void> createTeam(TeamCreateRequest request) async {
    if (teams.any((t) => t.teamName == request.teamName)) {
      _reject('이미 존재하는 팀명입니다.');
    }
    final manager =
        employees.firstWhere((e) => e.employeeId == request.projectManagerId);
    final id = ++_teamSeq;
    teams.add(_rebuild(
      Team(teamId: id, teamName: request.teamName),
      teamName: request.teamName,
      departmentId: request.departmentId,
      // 미지정 시 대표이사 팀 직속 (백엔드와 동일)
      parentTeamId: request.parentTeamId ?? 1,
      managers: [
        TeamManager(
          employeeId: manager.employeeId!,
          employeeNumber: manager.employeeNumber,
          name: manager.name,
          position: manager.position,
        ),
      ],
    ));
  }

  @override
  Future<void> updateTeam(int teamId, TeamUpdateRequest request) async {
    if (request.teamName != null &&
        teams.any((t) => t.teamName == request.teamName && t.teamId != teamId)) {
      _reject('이미 존재하는 팀명입니다.');
    }
    final index = teams.indexWhere((t) => t.teamId == teamId);
    List<TeamManager>? managers;
    if (request.projectManagerId != null) {
      final manager =
          employees.firstWhere((e) => e.employeeId == request.projectManagerId);
      managers = [
        TeamManager(
          employeeId: manager.employeeId!,
          employeeNumber: manager.employeeNumber,
          name: manager.name,
          position: manager.position,
        ),
      ];
    }
    teams[index] = _rebuild(
      teams[index],
      teamName: request.teamName,
      departmentId: request.departmentId,
      parentTeamId: request.parentTeamId,
      managers: managers,
    );
    _refreshDerivedNames();
  }

  @override
  Future<void> deleteTeam(int teamId) async {
    if (teams.any((t) => t.parentTeamId == teamId && t.teamId != teamId)) {
      _reject('하위 팀이 있는 팀은 삭제할 수 없습니다. 하위 팀을 먼저 정리해주세요.');
    }
    teams.removeWhere((t) => t.teamId == teamId);
  }

  @override
  Future<List<Employee>> searchEmployees(String? keyword) async {
    final q = keyword?.trim() ?? '';
    if (q.isEmpty) return List.of(employees);
    return employees
        .where((e) =>
            e.employeeNumber.toLowerCase().contains(q.toLowerCase()) ||
            e.name.contains(q))
        .toList();
  }
}
