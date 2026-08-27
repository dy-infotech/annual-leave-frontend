import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM004_D01.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

/// 사원 상세 화면(ADM004_D01) 특성화 테스트.
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
      'department': ['대표이사', '경영지원부'],
      'position': ['사원', '과장', '사장'],
      'accessibleTeam': ['SI사업팀', 'BI사업팀'],
    };
  });

  Employee targetEmployee() =>
      Employee.fromJson(fixtureJson('admin/employee.json'));

  Employee loginUser({String position = '과장'}) => Employee.fromJson(
      fixtureJson('admin/employee.json')..['position'] = position);

  Future<void> pumpDetailScreen(WidgetTester tester,
      {Employee? login}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      EmployeeDetailScreen(
        employee: targetEmployee(),
        repository: fake,
        commonCodeRepository: fakeCodes,
      ),
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => FakeAuthProvider(employeeInfo: login)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 사번, 연차 정보, 입사일이 표시된다', (tester) async {
    await pumpDetailScreen(tester, login: loginUser());

    expect(find.text('사용자 정보 상세'), findsOneWidget);
    expect(find.text('A0001'), findsOneWidget);
    expect(find.text('연차 : 11.5일 / 연차 : 15.0일'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('2020.01.01'), findsOneWidget); // 입사일 0패딩 포맷
    expect(find.text('등록'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget);
  });

  testWidgets('수정 저장 - 이메일을 바꿔 저장하면 수정 요청이 전송되고 잠금 모드로 돌아간다',
      (tester) async {
    await pumpDetailScreen(tester, login: loginUser());

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(find.text('저장'), findsOneWidget);

    // 이메일 필드 수정
    await tester.enterText(
        find.widgetWithText(TextFormField, 'hong@example.com'), 'new@example.com');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(fake.updates, hasLength(1));
    expect(fake.updates.single.employeeNumber, 'A0001');
    final data = fake.updates.single.data;
    expect(data['email'], 'new@example.com');
    expect(data['role'], 'EMPLOYEE');
    expect(data['hireDate'], '2020-01-01');
    expect(data['fireDate'], isNull);
    expect(data['password'], isNull);

    expect(find.text('사원 정보가 성공적으로 수정되었습니다.'), findsOneWidget);
    expect(find.text('수정'), findsOneWidget); // 저장 후 잠금 모드 복귀
  });

  testWidgets('일반 관리자 - 수정 모드여도 부서/팀/직급은 드롭다운이 아닌 읽기 전용이다', (tester) async {
    await pumpDetailScreen(tester, login: loginUser(position: '과장'));

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
  });

  testWidgets('사장 계정 - 수정 모드에서 부서/팀/직급 드롭다운이 노출된다', (tester) async {
    await pumpDetailScreen(tester, login: loginUser(position: '사장'));

    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
  });
}
