import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_request_screen.dart';
import 'screens/my_leave_requests_screen.dart';
import 'screens/all_leave_requests_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);  // 한글 날짜 포맷 초기화
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
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
        supportedLocales: const [
          Locale('ko', 'KR'),
        ],
        home: const SplashScreen(),
        navigatorObservers: [routeObserver],
        routes: {
          '/login': (context) => const LoginScreen(),                         // 로그인 화면
          '/signup': (context) => const SignupScreen(),                       // 사용 등록 화면
          '/dashboard': (context) => const DashboardScreen(),                 // 대시보드 화면
          '/leave-request': (context) => const LeaveRequestScreen(),          // 휴가 신청 화면
          '/my-leave-requests': (context) => const MyLeaveRequestsScreen(),   // 내 휴가 신청 목록 화면
          '/all-leave-requests': (context) => const AllLeaveRequestsScreen(), // 전직원 휴가 신청 목록 화면
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
    final auth = context.read<AuthProvider>();
    await auth.tryAutoLogin();

    if (!mounted) return;

    Navigator.pushReplacementNamed(context, auth.isLoggedIn ? '/dashboard' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
