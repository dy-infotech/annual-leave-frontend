import 'package:annual_leave_frontend/screens/search_employee_number_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show RemoteMessage, FirebaseMessaging;
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/leave_request_list_provider.dart';
import 'providers/public_holiday_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgotPasswordScreen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/leave_request_screen.dart';
//import 'screens/my_leave_requests_screen.dart';
import 'screens/all_leave_requests_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/my_info_screen.dart';
import 'screens/signup_manage_screen.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('백그라운드 FCM: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
        ChangeNotifierProvider(create: (_) => PublicHolidayProvider()),
        ChangeNotifierProvider(create: (_) => LeaveRequestListProvider()),
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
          '/forgot-password': (context) => const FindAccountScreen(),
          // 대시보드 화면
          '/dashboard': (context) => const DashboardScreen(),
          // 휴가 신청 화면
          '/leave-request': (context) => const LeaveRequestScreen(),
          // 내 휴가 신청 목록 화면
          //'/my-leave-requests': (context) => const MyLeaveRequestsScreen(),
          // 전직원 휴가 신청 목록 화면
          '/all-leave-requests': (context) => const AllLeaveRequestsScreen(),
          // 승인 대기 목록 화면
          '/pending-approval': (context) => const PendingApprovalScreen(),
          //사용자 등록 관리 화면
          '/signup_manage_screen': (context) => const SignupManageScreen(),
          //사용자 사번 조회 화면
          '/search_employee_number_screen': (context) =>
              const SearchEmployeeNumberScreen(),
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
    final auth = context.read<AuthProvider>();
    await auth.tryAutoLogin();

    if (!mounted) return;

    // 자동 로그인 성공 시, 공휴일 정보 조회
    if (auth.isLoggedIn) {
      await context.read<PublicHolidayProvider>().fetchPublicHoliday();
    }

    Navigator.pushReplacementNamed(
      context,
      auth.isLoggedIn ? '/dashboard' : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
