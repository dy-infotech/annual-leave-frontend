import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/features/auth/views/splash_screen.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/providers/dashboard_provider.dart';
import 'package:annual_leave_frontend/providers/leave_request_list_provider.dart';
import 'package:annual_leave_frontend/providers/public_holiday_provider.dart';
import 'package:annual_leave_frontend/screens/ADM001_M01.dart';
import 'package:annual_leave_frontend/screens/ADM002_M01.dart';
import 'package:annual_leave_frontend/screens/ADM003_M01.dart';
import 'package:annual_leave_frontend/screens/ADM004_M01.dart';
import 'package:annual_leave_frontend/screens/AUT001_M01.dart';
import 'package:annual_leave_frontend/screens/AUT002_M01.dart';
import 'package:annual_leave_frontend/screens/AUT003_M01.dart';
import 'package:annual_leave_frontend/screens/DSH001_M01.dart';
import 'package:annual_leave_frontend/screens/EMP001_M01.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE001_M01.dart';
//import 'package:annual_leave_frontend/features/leave/views/LVE002_M01.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M02.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE003_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

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
        debugShowCheckedModeBanner: false,
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
          // 결재 대기 목록 화면
          '/pending-approval': (context) => const PendingApprovalScreen(),
          //사용자 등록 관리 화면
          '/signup_manage_screen': (context) => const SignupManageScreen(),
          //사용자 사번 조회 화면
          '/search_employee_number_screen': (context) =>
              const SearchEmployeeNumberScreen(),
          //관리자별 관리팀 설정 화면
          '/admin-settings': (context) => const AdminSettingsScreen(),
          //부서 및 팀 관리 화면
          '/department-team-manage': (context) =>
              const DepartmentTeamManageScreen(),

          // 내 정보 화면
          '/my-info': (context) => const MyInfoScreen(),
        },
      ),
    );
  }
}
