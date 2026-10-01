import 'package:annual_leave_frontend/features/auth/auth_preferences.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 시작 화면. 저장된 로그인 상태를 복원(자동 로그인)한 뒤 대시보드 또는 로그인 화면으로 이동한다.
///
/// [holidayRepository]는 테스트에서 가짜 구현을 주입하기 위한 용도다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.holidayRepository});

  final PublicHolidayRepository? holidayRepository;

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
    final auth = context.read<AuthSession>();
    final prefs = await SharedPreferences.getInstance();
    final autoLoginEnabled =
        prefs.getBool(AuthPreferences.autoLoginKey) ??
            AuthPreferences.autoLoginDefault;

    await auth.tryAutoLogin(enabled: autoLoginEnabled);

    if (!mounted) return;

    // 자동 로그인 성공 시, 공휴일을 미리 조회해 캐시한다. (휴가 신청 화면에서 바로 사용)
    if (auth.isLoggedIn) {
      try {
        await (widget.holidayRepository ?? PublicHolidayRepository())
            .fetchPublicHolidays();
      } catch (_) {
        // 공휴일 조회 실패가 로그인 흐름을 막지 않도록 무시
      }
    }

    if (!mounted) return;
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
