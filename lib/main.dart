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
import 'screens/pending_approval_screen.dart';
import 'screens/my_info_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
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
        onGenerateRoute: _generateRoute,
      ),
    );
  }
}

Route<dynamic>? _generateRoute(RouteSettings settings) {
  final Widget child;
  var requiresAuthentication = true;
  var requiresAdmin = false;

  switch (settings.name) {
    case '/login':
      child = const LoginScreen();
      requiresAuthentication = false;
      break;
    case '/signup':
      child = const SignupScreen();
      requiresAuthentication = false;
      break;
    case '/dashboard':
      child = const DashboardScreen();
      break;
    case '/leave-request':
      child = const LeaveRequestScreen();
      break;
    case '/my-leave-requests':
      child = const MyLeaveRequestsScreen();
      break;
    case '/all-leave-requests':
      child = const AllLeaveRequestsScreen();
      break;
    case '/pending-approval':
      child = const PendingApprovalScreen();
      requiresAdmin = true;
      break;
    case '/my-info':
      child = const MyInfoScreen();
      break;
    default:
      return null;
  }

  return MaterialPageRoute(
    settings: settings,
    builder: (context) => _AuthorizedRoute(
      requiresAuthentication: requiresAuthentication,
      requiresAdmin: requiresAdmin,
      child: child,
    ),
  );
}

class _AuthorizedRoute extends StatelessWidget {
  final bool requiresAuthentication;
  final bool requiresAdmin;
  final Widget child;

  const _AuthorizedRoute({
    required this.requiresAuthentication,
    required this.requiresAdmin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (requiresAuthentication && !auth.isLoggedIn) {
      return const LoginScreen();
    }
    if (requiresAdmin && !auth.isAdmin) {
      return const _AccessDeniedScreen();
    }
    return child;
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('접근 권한 없음')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          ),
          child: const Text('대시보드로 이동'),
        ),
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
