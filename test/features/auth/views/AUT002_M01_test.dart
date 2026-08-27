import 'package:annual_leave_frontend/features/auth/views/AUT002_M01.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';

/// 사용자 등록 화면(AUT002_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다. (주입 배선만 변경 가능)
void main() {
  late FakeAuthProvider fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthProvider();
  });

  Future<void> pumpSignupScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => fakeAuth),
      ],
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('유효성 - 빈 입력과 비밀번호 불일치 안내가 표시된다', (tester) async {
    await pumpSignupScreen(tester);

    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();
    expect(find.text('사번과 비밀번호를 입력해 주세요.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'pw1');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), 'pw2');
    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 일치하지 않습니다.'), findsOneWidget);

    expect(fakeAuth.signUpCalls, isEmpty);
  });

  testWidgets('등록 성공 - 대문자 사번으로 전송되고 완료 안내 후 이전 화면으로 돌아간다', (tester) async {
    await pumpSignupScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'pw1');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), 'pw1');
    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();

    expect(fakeAuth.signUpCalls, [
      {'employeeNumber': 'A0001', 'password': 'pw1'},
    ]);
    expect(find.text('사용 등록이 완료되었습니다. 로그인해 주세요.'), findsOneWidget);
    expect(find.text('go'), findsOneWidget); // 이전 화면 복귀
  });

  testWidgets('등록 실패 - 실패 안내가 표시된다', (tester) async {
    fakeAuth.signUpErrorToThrow = Exception('already used');

    await pumpSignupScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'pw1');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호 확인'), 'pw1');
    await tester.tap(find.text('등록하기'));
    await tester.pumpAndSettle();

    expect(find.text('사용 등록에 실패했습니다.'), findsOneWidget);
  });
}
