import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM002_M01.dart';
import 'package:annual_leave_frontend/features/auth/models/enums/RoleType.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_session.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';
import '../../../helpers/test_doubles/fake_signup_manage_repository.dart';

/// 사용자 등록 관리 화면(ADM002_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeSignupManageRepository fake;
  late FakeCommonCodeRepository fakeCodes;

  setUp(() {
    fake = FakeSignupManageRepository();
    fakeCodes = FakeCommonCodeRepository();
    fakeCodes.codesToReturn = {
      'department': ['대표이사', '경영지원부'],
      'position': ['사원', '과장', '사장'],
      'accessibleTeam': ['대표이사', 'SI사업팀', 'BI사업팀'],
    };
  });

  Employee loginUser({String position = '과장', String role = 'EMPLOYEE'}) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['position'] = position
        ..['role'] = role
        ..['department'] = '경영지원부');

  Future<void> pumpSignupScreen(WidgetTester tester, {Employee? login}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      SignupManageScreen(
        repository: fake,
        commonCodeRepository: fakeCodes,
      ),
      providers: [
        ChangeNotifierProvider<AuthSession>(
            create: (_) => FakeAuthSession(employeeInfo: login)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진입 - 안내 문구와 오늘 날짜 입사일 기본값이 표시된다', (tester) async {
    await pumpSignupScreen(tester, login: loginUser());

    expect(find.text('사용자 등록 관리'), findsOneWidget);
    expect(find.textContaining('신규 사용자 정보를 등록합니다.'), findsOneWidget);

    final today = DateTime.now();
    expect(find.text('${today.year}년 ${today.month}월 ${today.day}일'),
        findsOneWidget);
  });

  testWidgets('유효성 - 사번이 비어 있으면 안내 메시지가 표시된다', (tester) async {
    await pumpSignupScreen(tester, login: loginUser());

    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();

    expect(find.text('사번을 입력해 주세요.'), findsOneWidget);
    expect(fake.registeredRequests, isEmpty);
  });

  testWidgets('부서 필터 - 사장이 아니면 본인 소속 부서만 선택지에 남는다', (tester) async {
    await pumpSignupScreen(tester, login: loginUser(position: '과장'));

    await tester.tap(find.text('부서'));
    await tester.pumpAndSettle();

    expect(find.text('경영지원부'), findsWidgets);
    expect(find.text('대표이사'), findsNothing);
  });

  testWidgets('역할 필터 - 사장+관리자만 관리자 항목이 보인다', (tester) async {
    await pumpSignupScreen(tester,
        login: loginUser(position: '사장', role: 'ADMIN'));

    await tester.tap(find.text(RoleType.employee.label).last);
    await tester.pumpAndSettle();

    expect(find.text(RoleType.admin.label), findsOneWidget);
  });

  testWidgets('역할 필터 - 대표이사 직급 관리자도 관리자 항목이 보인다', (tester) async {
    await pumpSignupScreen(tester,
        login: loginUser(position: '대표이사', role: 'ADMIN'));

    await tester.tap(find.text(RoleType.employee.label).last);
    await tester.pumpAndSettle();

    expect(find.text(RoleType.admin.label), findsOneWidget);
  });

  testWidgets('등록 성공 - 입력값이 요청으로 전송되고 완료 안내가 표시된다', (tester) async {
    await pumpSignupScreen(tester, login: loginUser());

    await tester.enterText(
        find.widgetWithText(TextField, '사번'), 'a0009');
    await tester.enterText(
        find.widgetWithText(TextField, '사용자명'), '최신규');
    await tester.enterText(
        find.widgetWithText(TextField, '이메일'), 'choi@example.com');

    // 부서 선택 (사장 아님 -> 본인 부서만)
    await tester.tap(find.text('부서'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('경영지원부').last);
    await tester.pumpAndSettle();

    // 팀 선택 (대표이사 팀 제외)
    await tester.tap(find.text('팀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SI사업팀').last);
    await tester.pumpAndSettle();

    // 직급 선택
    await tester.tap(find.text('직급'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사원').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('등록하기'));
    // 등록 성공 시 대시보드로 이동하며 무한 애니메이션이 있어 시간 고정 pump 사용
    await pumpFor(tester, duration: const Duration(seconds: 1));

    expect(fake.registeredRequests, hasLength(1));
    final req = fake.registeredRequests.single.toJson();
    expect(req['employeeNumber'], 'A0009'); // 대문자 자동 변환
    expect(req['name'], '최신규');
    expect(req['department'], '경영지원부');
    expect(req['team'], 'SI사업팀');
    expect(req['position'], '사원');
    expect(req['role'], 'EMPLOYEE');
    expect(req['email'], 'choi@example.com');
    final today = DateTime.now();
    expect(
      req['hireDate'],
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    );

    expect(find.text('사용자 등록이 완료되었습니다. 사용 등록 후 로그인 가능합니다.'), findsOneWidget);
  });
}
