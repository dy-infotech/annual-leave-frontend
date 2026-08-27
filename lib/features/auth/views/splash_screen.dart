import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/providers/public_holiday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
