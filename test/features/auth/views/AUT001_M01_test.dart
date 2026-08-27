import 'package:annual_leave_frontend/features/auth/views/AUT001_M01.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';

/// 로그인 화면(AUT001_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다. (주입 배선만 변경 가능)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  late FakeAuthProvider fakeAuth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeAuth = FakeAuthProvider();
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const LoginScreen(),
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => fakeAuth),
      ],
      routes: {
        '/dashboard': (_) => const Scaffold(body: Text('dashboard-stub')),
        '/signup': (_) => const Scaffold(body: Text('signup-stub')),
        '/forgot-password': (_) => const Scaffold(body: Text('forgot-stub')),
      },
    );
    await tester.pumpAndSettle();
  }

  testWidgets('진입 - 로고와 안내 문구, 입력란이 표시된다', (tester) async {
    await pumpLoginScreen(tester);

    expect(find.text('DY'), findsOneWidget);
    expect(find.text('디와이정보기술 임직원 전용 연차 관리 시스템'), findsOneWidget);
    expect(find.widgetWithText(TextField, '사번'), findsOneWidget);
  });

  testWidgets('로그인 - 사번/비밀번호가 비어 있으면 안내가 표시된다', (tester) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.text('사번과 비밀번호를 입력해주세요.'), findsOneWidget);
    expect(fakeAuth.loginCalls, isEmpty);
  });

  testWidgets('로그인 성공 - 사번이 대문자로 변환되어 전송되고 대시보드로 이동한다', (tester) async {
    await pumpLoginScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'pw1234');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(fakeAuth.loginCalls, [
      {'employeeNumber': 'A0001', 'password': 'pw1234'},
    ]);
    expect(find.text('dashboard-stub'), findsOneWidget);
  });

  testWidgets('로그인 실패 - 오류 메시지가 표시된다', (tester) async {
    fakeAuth.loginErrorToThrow = Exception('로그인 실패');

    await pumpLoginScreen(tester);

    await tester.enterText(find.widgetWithText(TextField, '사번'), 'a0001');
    await tester.enterText(find.widgetWithText(TextField, '비밀번호'), 'bad');
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();

    expect(find.textContaining('로그인 실패'), findsOneWidget);
    expect(find.text('dashboard-stub'), findsNothing);
  });
}
