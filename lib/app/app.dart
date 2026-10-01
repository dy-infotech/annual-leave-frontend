import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/core/services/fcm_service.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/features/auth/views/splash_screen.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM001_M01.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM002_M01.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM003_M01.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM004_M01.dart';
import 'package:annual_leave_frontend/features/auth/views/AUT001_M01.dart';
import 'package:annual_leave_frontend/features/auth/views/AUT002_M01.dart';
import 'package:annual_leave_frontend/features/auth/views/AUT003_M01.dart';
import 'package:annual_leave_frontend/features/dashboard/views/DSH001_M01.dart';
import 'package:annual_leave_frontend/features/employee/views/EMP001_M01.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE001_M01.dart';
//import 'package:annual_leave_frontend/features/leave/views/LVE002_M01.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M02.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE003_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

/// 화면 전환 이벤트를 감시하는 옵저버. 다른 화면에서 돌아왔을 때 목록을 갱신하는 데 쓴다.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 앱 최상위 Navigator의 키. BuildContext가 없는 곳(세션 만료 콜백 등)에서 화면을 전환할 때 쓴다.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 앱 루트 위젯.
///
/// - 앱 전체에서 공유하는 상태는 [AuthSession] 하나뿐이다. 나머지 상태는 화면마다 ViewModel로 관리한다.
/// - 라우트는 모두 이름 있는 라우트(`routes`)로 등록하며, 라우트 자체에는 인증 가드가 없다.
///   로그인 여부는 SplashScreen의 자동 로그인과 서버의 401 응답(세션 만료 콜백)으로 처리한다.
/// - 관리자 메뉴 노출은 `AppDrawer`에서 하며, 실제 접근 권한은 서버가 검증한다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final session = AuthSession();
            // 세션 만료(refresh 실패 등)가 확정되면 로그인 상태를 지우고 로그인 화면으로 돌려보낸다.
            ApiClient().setUnauthorizedHandler((expiredGeneration) async {
              // 만료가 확정된 뒤 이미 로그아웃/재로그인으로 세션이 바뀌었다면 무시한다.
              if (ApiClient().sessionGeneration != expiredGeneration) return;

              // 인증 상태와 화면 전환을 Firebase 정리보다 먼저 확정한다.
              final shouldRedirect = session.expireSession();
              if (shouldRedirect) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
                    '/login',
                    (_) => false,
                  );
                });
              }

              // FCM 정리는 외부 SDK 실패와 무관하게 best-effort로 수행한다.
              try {
                await FcmService.instance.clearLocalStateAfterSessionExpiry(
                  expectedAuthGeneration: expiredGeneration,
                );
              } catch (e) {
                debugPrint('FCM 세션 만료 정리 실패: $e');
              }
            });
            return session;
          },
        ),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
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
        // 첫 화면: 자동 로그인을 시도한 뒤 대시보드 또는 로그인 화면으로 이동한다.
        home: const SplashScreen(),
        navigatorObservers: [routeObserver],
        routes: {
          // 로그인 화면
          '/login': (context) => const LoginScreen(),
          // 사용 등록 화면
          '/signup': (context) => const SignupScreen(),
          // 비번찾기 화면
          '/forgot-password': (context) => const FindAccountScreen(),
          // 대시보드 화면. 진입 시 내 정보(/me)를 먼저 갱신해 권한/메뉴 상태를 최신으로 맞춘다.
          '/dashboard': (context) => DashboardScreen(
                refreshSession: context.read<AuthSession>().fetchMyInfo,
              ),
          // 휴가 신청 화면
          '/leave-request': (context) => const LeaveRequestScreen(),
          // 내 신청 전용 화면(LVE002_M01)은 라우트에 등록하지 않는다.
          // 내 신청 목록은 '/all-leave-requests' 화면의 "내 신청" 모드가 제공한다.
          //'/my-leave-requests': (context) => const MyLeaveRequestsScreen(),
          // 전직원 휴가 신청 목록 화면 ("내 신청" 모드 포함)
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
