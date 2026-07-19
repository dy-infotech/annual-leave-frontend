import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/api_client.dart';
import 'features/dashboard/view/dashboard_screen.dart';
import 'features/auth/model/api_client/auth_api_client.dart';
import 'features/auth/viewmodel/auth_session_viewmodel.dart';
import 'features/auth/view/login_screen.dart';
import 'features/profile/model/api_client/profile_api_client.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';
import 'features/profile/view/my_info_screen.dart';
import 'features/signup/view/signup_screen.dart';
import 'features/password_reset/view/forgot_password_screen.dart';
import 'features/admin_registration/view/signup_manage_screen.dart';
import 'features/public_holiday/model/api_client/public_holiday_api_client.dart';
import 'features/public_holiday/viewmodel/public_holiday_viewmodel.dart';
import 'features/leave_request/create/view/leave_request_screen.dart';
import 'features/leave_request/list/view/all_leave_requests_screen.dart';
import 'features/leave_request/approval/view/pending_approval_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await initializeDateFormatting('ko_KR', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 전역 상태 (여러 화면이 공유해서 구독)
        ChangeNotifierProvider(create: (_) => AuthSessionViewModel(AuthApiClient(ApiClient()))),
        ChangeNotifierProvider(create: (_) => ProfileViewModel(ProfileApiClient(ApiClient()))),
        ChangeNotifierProvider(create: (_) => PublicHolidayViewModel(PublicHolidayApiClient(ApiClient()))),
      ],

      child: MaterialApp(
        title: '연차 관리',
        theme: AppTheme.theme,
        locale: const Locale('ko', 'KR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR')],
        home: const SplashScreen(),
        navigatorObservers: [routeObserver],
        routes: {
          // 로그인 화면
          '/login': (context) => const LoginScreen(),
          // 사용 등록 화면
          '/signup': (context) => const SignupScreen(),
          // 비번찾기 화면
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          // 대시보드 화면
          '/dashboard': (context) => const DashboardScreen(),
          // 휴가 신청 화면
          '/leave-request': (context) => const LeaveRequestScreen(),
          // 전직원 휴가 신청 목록 화면
          '/all-leave-requests': (context) => const AllLeaveRequestsScreen(),
          // 승인 대기 목록 화면
          '/pending-approval': (context) => const PendingApprovalScreen(),
          //사용자 등록 관리 화면
          '/signup_manage_screen': (context) => const SignupManageScreen(),
          // 내 정보 화면
          '/my-info': (context) => const MyInfoScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final session = context.read<AuthSessionViewModel>();
    final profile = context.read<ProfileViewModel>();

    // 1) 로컬에 저장된 토큰이 있는지만 우선 확인 (AuthSessionViewModel의 책임)
    await session.tryAutoLogin();

    if (!mounted) return;

    if (session.isLoggedIn) {
      // 2) 토큰이 실제로 유효한지는 "내 정보 조회"가 성공하는지로 검증한다.
      //    (내 정보는 ProfileViewModel의 책임이라 View가 순서대로 조합)
      try {
        await profile.fetchMyInfo();
      } catch (e) {
        // 토큰 만료 등으로 조회 실패 시, 세션을 되돌리고 로그인 화면으로 유도
        await session.invalidateSession();
      }
    }

    if (!mounted) return;

    // 자동 로그인 성공 시, 공휴일 정보 조회
    if (session.isLoggedIn) {
      await context.read<PublicHolidayViewModel>().fetchPublicHoliday();
    }

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      session.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
