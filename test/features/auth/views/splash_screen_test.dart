import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/auth/views/splash_screen.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:provider/provider.dart';

import '../../../helpers/pump_app.dart';

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

  setUpAll(() {
    // JWT 조회가 플랫폼 채널을 타므로 null을 돌려주도록 모킹한다.
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  setUp(() {
    // 공휴일 저장소가 static 캐시를 쓰므로 테스트 간 간섭을 막는다.
    PublicHolidayRepository.clearCache();

    // 자동 로그인 성공 경로에서 화면이 공휴일 API를 직접 호출한다.
    // 저장소를 주입할 수 없는 구조라 HTTP 계층에서 스텁한다.
    final dioAdapter = DioAdapter(dio: ApiClient().dio);
    dioAdapter
      ..onGet('/api/leave-requests/current-year-special-days',
          (server) => server.reply(200, []))
      ..onGet('/api/leave-requests/next-year-special-days',
          (server) => server.reply(200, []));
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
      const SplashScreen(),
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
    await tester.pumpAndSettle();

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
}
