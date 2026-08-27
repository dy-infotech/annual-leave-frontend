import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/employee/views/EMP001_M01.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';
import '../../../helpers/test_doubles/fake_employee_repository.dart';

/// 내 정보 화면(EMP001_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeEmployeeRepository fake;
  late FakeAuthProvider fakeAuth;

  setUp(() {
    fake = FakeEmployeeRepository();
    fakeAuth = FakeAuthProvider(
      employeeInfo: Employee.fromJson(fixtureJson('admin/employee.json')),
    );
  });

  Future<void> pumpMyInfoScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      MyInfoScreen(repository: fake),
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => fakeAuth),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 기본 정보가 표시된다', (tester) async {
    await pumpMyInfoScreen(tester);

    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('A0001'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('과장'), findsOneWidget);
    expect(find.text('경영지원부'), findsOneWidget);
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('11.5 / 15.0 일'), findsOneWidget);
    expect(find.text('hong@example.com'), findsOneWidget);
  });

  testWidgets('이메일 변경 - 편집 후 저장하면 API와 세션 갱신이 수행된다', (tester) async {
    await pumpMyInfoScreen(tester);

    // 편집 시작: 기존 이메일이 입력란에 채워진다
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'hong@example.com'))
          .controller
          ?.text,
      'hong@example.com',
    );

    await tester.enterText(
        find.widgetWithText(TextField, 'hong@example.com'), 'new@example.com');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(fake.emailChanges, ['new@example.com']);
    expect(fakeAuth.updatedEmails, ['new@example.com']);
    expect(find.text('이메일이 변경되었습니다.'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget); // 편집 모드 종료
  });

  testWidgets('이메일 변경 - 형식이 잘못되면 안내가 표시되고 전송하지 않는다', (tester) async {
    await pumpMyInfoScreen(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'hong@example.com'), 'invalid-email');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
    expect(fake.emailChanges, isEmpty);
  });

  testWidgets('비밀번호 변경 - 검증 규칙이 순서대로 적용된다', (tester) async {
    await pumpMyInfoScreen(tester);

    await tester.tap(find.text('비밀번호 변경').last);
    await tester.pumpAndSettle();
    expect(find.text('모든 항목을 입력해주세요.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '현재 비밀번호'), 'old1');
    await tester.enterText(find.widgetWithText(TextField, '새 비밀번호'), 'new1');
    await tester.enterText(
        find.widgetWithText(TextField, '새 비밀번호 확인'), 'new2');
    await tester.tap(find.text('비밀번호 변경').last);
    await tester.pumpAndSettle();
    expect(find.text('새 비밀번호가 일치하지 않습니다.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '새 비밀번호'), 'old1');
    await tester.enterText(
        find.widgetWithText(TextField, '새 비밀번호 확인'), 'old1');
    await tester.tap(find.text('비밀번호 변경').last);
    await tester.pumpAndSettle();
    expect(find.text('현재 비밀번호와 다른 비밀번호를 입력해주세요.'), findsOneWidget);

    expect(fake.passwordChanges, isEmpty);
  });

  testWidgets('비밀번호 변경 성공 - 요청이 전송되고 입력이 초기화된다', (tester) async {
    await pumpMyInfoScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '현재 비밀번호'), 'old1');
    await tester.enterText(find.widgetWithText(TextField, '새 비밀번호'), 'new1');
    await tester.enterText(
        find.widgetWithText(TextField, '새 비밀번호 확인'), 'new1');
    await tester.tap(find.text('비밀번호 변경').last);
    await tester.pumpAndSettle();

    expect(fake.passwordChanges, [
      {'currentPassword': 'old1', 'newPassword': 'new1'},
    ]);
    expect(find.text('비밀번호가 변경되었습니다.'), findsOneWidget);
  });

  testWidgets('비밀번호 변경 실패 - 실패 안내가 표시된다', (tester) async {
    fake.changePasswordErrorToThrow = Exception('wrong password');

    await pumpMyInfoScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '현재 비밀번호'), 'old1');
    await tester.enterText(find.widgetWithText(TextField, '새 비밀번호'), 'new1');
    await tester.enterText(
        find.widgetWithText(TextField, '새 비밀번호 확인'), 'new1');
    await tester.tap(find.text('비밀번호 변경').last);
    await tester.pumpAndSettle();

    expect(find.text('현재 비밀번호가 일치하지 않거나 변경에 실패했습니다.'), findsOneWidget);
  });
}
