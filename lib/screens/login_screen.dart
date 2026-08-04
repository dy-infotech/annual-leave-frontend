import 'package:annual_leave_frontend/providers/public_holiday_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // 👈 암호화 저장소 임포트
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  bool _isRememberMe = false;

  // 💾 비밀번호 전용 안전 저장소 객체 생성
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSavedAccountInfo(); // 👈 사번 및 비밀번호 일괄 자동 로드
  }

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 💾 로컬 저장소에서 계정 정보(사번 + 비밀번호) 불러오기
  Future<void> _loadSavedAccountInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() async {
      _isRememberMe = prefs.getBool('isRememberMe') ?? false;
      if (_isRememberMe) {
        // 일반 설정에서 사번 로드
        _employeeNumberController.text =
            prefs.getString('savedEmployeeNumber') ?? '';
        // 암호화 공간에서 비밀번호 꺼내오기
        final savedPassword =
            await _secureStorage.read(key: 'savedPassword') ?? '';
        _passwordController.text = savedPassword;
      }
    });
  }

  // 💾 로그인 성공 시 계정 정보(사번 + 암호화 비밀번호) 저장 처리
  Future<void> _saveAccountInfoPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isRememberMe) {
      // 사번 일반 저장
      await prefs.setBool('isRememberMe', true);
      await prefs.setString(
          'savedEmployeeNumber', _employeeNumberController.text.trim());
      // 비밀번호 안전하게 암호화 저장
      await _secureStorage.write(
          key: 'savedPassword', value: _passwordController.text);
    } else {
      // 체크 해제 시 데이터 전부 일괄 소거
      await prefs.remove('isRememberMe');
      await prefs.remove('savedEmployeeNumber');
      await _secureStorage.delete(key: 'savedPassword'); // 암호 저장소 삭제
    }
  }

  Future<void> _handleLogin() async {
    if (_employeeNumberController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = '사번과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().login(
            _employeeNumberController.text.trim(),
            _passwordController.text,
          );

      // 로그인이 최종 성공한 시점에 로컬 저장소 값 업데이트 수행 (사번+비번)
      await _saveAccountInfoPreference();

      if (mounted) {
        await context.read<PublicHolidayProvider>().fetchPublicHoliday();
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DY',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 84,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: AppColors.slate,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'INFOTECH',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '디와이정보기술 임직원 전용 연차 관리 시스템',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.slate,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      TextField(
                        controller: _employeeNumberController,
                        decoration: const InputDecoration(
                          labelText: '사번',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 18, horizontal: 16),
                        ),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        obscureText: true,
                        onSubmitted: (_) => _handleLogin(),
                      ),

                      const SizedBox(height: 8),

                      // 🛠️ 계정 정보(사번+비번) 저장 체크박스 UI 레이아웃 영역
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _isRememberMe,
                              activeColor: AppColors.slate, // 테마 컬러 연동
                              onChanged: (value) {
                                setState(() {
                                  _isRememberMe = value ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isRememberMe =
                                    !_isRememberMe; // 텍스트 영역 클릭 시에도 토글
                              });
                            },
                            child: const Text(
                              '계정 정보 저장', // 👈 직관적으로 인지하도록 문구 수정
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.slate,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.coral,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('로그인'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/signup'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.slate,
                            side: const BorderSide(
                              color: AppColors.textMuted,
                              width: 1.3,
                            ),
                          ),
                          child: const Text('사용 등록'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password'),
                          child: const Text('아이디/비밀번호 찾기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
