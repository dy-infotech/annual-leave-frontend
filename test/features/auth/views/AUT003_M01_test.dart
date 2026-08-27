import 'package:annual_leave_frontend/features/auth/views/AUT003_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_repository.dart';

/// 계정 찾기 화면(AUT003_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다. (주입 배선만 변경 가능)
void main() {
  late FakeAuthRepository fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthRepository();
  });

  Future<void> pumpFindAccountScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FindAccountScreen(repository: fakeAuth)),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('아이디 찾기 - 빈 입력이면 안내가 표시된다', (tester) async {
    await pumpFindAccountScreen(tester);

    expect(find.text('계정 정보 찾기'), findsOneWidget);
    await tester.tap(find.text('이메일 전송'));
    await tester.pumpAndSettle();

    expect(find.text('성함과 이메일을 모두 입력해 주세요.'), findsOneWidget);
    expect(fakeAuth.findIdCalls, isEmpty);
  });

  testWidgets('아이디 찾기 성공 - 요청이 전송되고 안내 후 이전 화면으로 돌아간다', (tester) async {
    await pumpFindAccountScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '성함'), ' 홍길동 ');
    await tester.enterText(
        find.widgetWithText(TextField, '이메일 주소'), 'hong@example.com');
    await tester.tap(find.text('이메일 전송'));
    await tester.pumpAndSettle();

    expect(fakeAuth.findIdCalls, [
      {'name': '홍길동', 'email': 'hong@example.com'},
    ]);
    expect(find.text('아이디를 성공적으로 전송하였습니다.'), findsOneWidget);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('아이디 찾기 실패 - 안내가 표시된다', (tester) async {
    fakeAuth.findIdErrorToThrow = Exception('not found');

    await pumpFindAccountScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '성함'), '홍길동');
    await tester.enterText(
        find.widgetWithText(TextField, '이메일 주소'), 'x@example.com');
    await tester.tap(find.text('이메일 전송'));
    await tester.pumpAndSettle();

    expect(find.text('등록된 정보가 일치하지 않습니다.'), findsOneWidget);
  });

  testWidgets('비밀번호 찾기 - 탭 전환 후 사번이 대문자로 전송되고 안내가 표시된다', (tester) async {
    await pumpFindAccountScreen(tester);

    await tester.tap(find.text('비밀번호 찾기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(
        find.widgetWithText(TextField, '이메일 주소'), 'hong@example.com');
    await tester.tap(find.text('이메일 전송'));
    await tester.pumpAndSettle();

    expect(fakeAuth.resetCalls, [
      {'employeeNumber': 'A0001', 'email': 'hong@example.com'},
    ]);
    expect(find.text('비밀번호 재설정 이메일이 발송되었습니다.'), findsOneWidget);
  });

  testWidgets('비밀번호 찾기 실패 - 안내가 표시된다', (tester) async {
    fakeAuth.resetErrorToThrow = Exception('mismatch');

    await pumpFindAccountScreen(tester);

    await tester.tap(find.text('비밀번호 찾기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(
        find.widgetWithText(TextField, '이메일 주소'), 'x@example.com');
    await tester.tap(find.text('이메일 전송'));
    await tester.pumpAndSettle();

    expect(find.text('등록된 정보가 일치하지 않거나 발송에 실패했습니다.'), findsOneWidget);
  });
}
