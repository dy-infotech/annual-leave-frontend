import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM001_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

/// 관리자별 관리팀 설정 화면(ADM001_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeAdminEmployeeRepository fake;
  late FakeCommonCodeRepository fakeCodes;

  setUp(() {
    fake = FakeAdminEmployeeRepository();
    fakeCodes = FakeCommonCodeRepository();
    fakeCodes.codesToReturn = {
      'department': ['대표이사'],
      'position': ['사원'],
      'accessibleTeam': ['SI사업팀', 'BI사업팀', '경영지원팀'],
    };
  });

  Employee employee({
    String employeeNumber = 'A0001',
    String name = '홍길동',
    String role = 'EMPLOYEE',
    List<String>? teamList,
  }) {
    final json = fixtureJson('admin/employee.json')
      ..['employeeNumber'] = employeeNumber
      ..['name'] = name
      ..['role'] = role
      ..['teamList'] = teamList;
    return Employee.fromJson(json);
  }

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 기존 화면의 알려진 디버그 단언(ListTile이 배경색 있는 DecoratedBox 안에 있음)은
    // 현재 동작 그대로 기록하기 위해 테스트에서만 무시한다.
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception
          .toString()
          .contains('ListTile background color or ink splashes')) {
        return;
      }
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);

    await pumpApp(
      tester,
      AdminSettingsScreen(
        repository: fake,
        commonCodeRepository: fakeCodes,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 사원 목록이 표시되고 첫 사원이 자동 선택된다', (tester) async {
    fake.employeesToReturn = [
      employee(role: 'ADMIN', teamList: ['SI사업팀']),
      employee(employeeNumber: 'B0002', name: '김일반'),
    ];

    await pumpSettingsScreen(tester);

    expect(find.text('관리자별 관리팀 설정'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('김일반'), findsOneWidget);
    // 첫 사원(관리자)의 관리팀에 SI사업팀, 팀 목록에 나머지
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('BI사업팀'), findsOneWidget);
    expect(find.text('경영지원팀'), findsOneWidget);
  });

  testWidgets('일반 사원 선택 - 관리팀이 비고 전체 팀이 팀 목록에 나온다', (tester) async {
    fake.employeesToReturn = [
      employee(role: 'ADMIN', teamList: ['SI사업팀']),
      employee(employeeNumber: 'B0002', name: '김일반'),
    ];

    await pumpSettingsScreen(tester);

    await tester.tap(find.text('김일반'));
    await tester.pumpAndSettle();

    // 관리팀 패널이 비어 있으므로 세 팀 모두 팀 목록에만 존재
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('BI사업팀'), findsOneWidget);
    expect(find.text('경영지원팀'), findsOneWidget);
  });

  testWidgets('팀 이동 - 팀을 더블탭하면 관리팀으로 이동한다', (tester) async {
    fake.employeesToReturn = [employee()];

    await pumpSettingsScreen(tester);

    // 더블탭 = 선택 + 이동 (기존 화면이 지원하는 제스처)
    await tester.tap(find.text('BI사업팀'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('BI사업팀'));
    await tester.pumpAndSettle();

    // 이동 후에도 화면에는 한 번만 존재 (관리팀 패널로 이동)
    expect(find.text('BI사업팀'), findsOneWidget);
  });

  testWidgets('저장 - 변경된 팀 목록이 targetTeamsForRoleSwap으로 전송된다', (tester) async {
    fake.employeesToReturn = [employee()];

    await pumpSettingsScreen(tester);

    await tester.tap(find.text('BI사업팀'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('BI사업팀'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('변경 사항 저장하기'));
    await tester.pumpAndSettle();

    expect(fake.updates, hasLength(1));
    expect(fake.updates.single.employeeNumber, 'A0001');
    expect(fake.updates.single.data['targetTeamsForRoleSwap'], ['BI사업팀']);
    // 저장 후 목록 재조회
    expect(fake.fetchQueries.length, 2);
  });
}
