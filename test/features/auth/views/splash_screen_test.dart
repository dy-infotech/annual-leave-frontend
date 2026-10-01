import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/auth/views/splash_screen.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_public_holiday_repository.dart';

/// 스플래시 화면의 자동 로그인 분기 테스트.
///
/// 자동 로그인 성공 여부에 따라 대시보드 또는 로그인 화면으로 갈라진다.
class _StubAuthSession extends AuthSession {
  _StubAuthSession({required this.loggedIn, this.errorToThrow});

  final bool loggedIn;
  final Object? errorToThrow;

  int tryAutoLoginCount = 0;
  bool _isLoggedIn = false;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  Future<void> tryAutoLogin() async {
    tryAutoLoginCount++;
    if (errorToThrow != null) throw errorToThrow!;
    _isLoggedIn = loggedIn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PublicHolidayRepository.clearCache();
    SharedPreferences.setMockInitialValues({});
  });

  Future<_StubAuthSession> pumpSplash(
    WidgetTester tester, {
    required bool loggedIn,
    Object? errorToThrow,
  }) async {
    final session =
        _StubAuthSession(loggedIn: loggedIn, errorToThrow: errorToThrow);

    await pumpApp(
      tester,
      SplashScreen(
        holidayRepository: FakePublicHolidayRepository(),
      ),
      providers: [ChangeNotifierProvider<AuthSession>.value(value: session)],
      routes: {
        '/dashboard': (_) => const Scaffold(body: Text('dashboard-stub')),
        '/login': (_) => const Scaffold(body: Text('login-stub')),
      },
    );
    return session;
  }

  testWidgets('진입 즉시 로딩 표시를 보여준다', (tester) async {
    await pumpSplash(tester, loggedIn: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('자동 로그인 성공 - 대시보드로 이동한다', (tester) async {
    final session = await pumpSplash(tester, loggedIn: true);
    await pumpUntilFound(tester, find.text('dashboard-stub'));

    expect(session.tryAutoLoginCount, 1);
    expect(find.text('dashboard-stub'), findsOneWidget);
    expect(find.text('login-stub'), findsNothing);
  });

  testWidgets('자동 로그인 실패 - 로그인 화면으로 이동한다', (tester) async {
    final session = await pumpSplash(tester, loggedIn: false);
    await tester.pumpAndSettle();

    expect(session.tryAutoLoginCount, 1);
    expect(find.text('login-stub'), findsOneWidget);
    expect(find.text('dashboard-stub'), findsNothing);
  });

  testWidgets('자동 로그인 해제 - 세션 복원을 시도하지 않고 로그인 화면으로 이동한다',
      (tester) async {
    SharedPreferences.setMockInitialValues({'autoLoginEnabled': false});

    final session = await pumpSplash(tester, loggedIn: true);
    await tester.pumpAndSettle();

    expect(session.tryAutoLoginCount, 0);
    expect(find.text('login-stub'), findsOneWidget);
    expect(find.text('dashboard-stub'), findsNothing);
  });
}
