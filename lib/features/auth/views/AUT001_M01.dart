// AUT001_M01: 로그인 화면
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/auth/view_models/AUT001_M01_view_model.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(), // 입력된 텍스트를 대문자로 변환
      selection: newValue.selection, // 커서 위치 유지
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.holidayRepository});

  final PublicHolidayRepository? holidayRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(
        authSession: context.read<AuthSession>(),
        holidayRepository: holidayRepository,
      )..loadSavedAccountInfo(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  LoginViewModel get _vm => context.read<LoginViewModel>();

  Future<void> _handleLogin() async {
    final ok = await _vm.login();
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LoginViewModel>();
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
                      // const SizedBox(height: 12),
                      // TextField(
                      //   controller: _vm.employeeNumberController,
                      //   decoration: const InputDecoration(
                      //     labelText: '사번',
                      //     border: OutlineInputBorder(),
                      //     contentPadding: EdgeInsets.symmetric(
                      //         vertical: 18, horizontal: 16),
                      //   ),
                      //   keyboardType: TextInputType.text,
                      //   textCapitalization: TextCapitalization.characters,
                      // ),

                      const SizedBox(height: 12),
                      TextField(
                        controller: _vm.employeeNumberController,
                        decoration: const InputDecoration(
                          labelText: '사번',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 18, horizontal: 16),
                        ),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        // 아래 속성을 추가하면 입력되는 모든 영문자가 대문자로 강제 변환됩니다.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')), // 필요한 경우 영문/숫자만 허용
                          UpperCaseTextFormatter(), // 대문자 변환 포매터 적용
                        ],
                      ),

                      const SizedBox(height: 12),
                      TextField(
                        controller: _vm.passwordController,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        obscureText: true,
                        onSubmitted: (_) => _handleLogin(),
                      ),

                      const SizedBox(height: 8),

                      // 사번 저장과 자동 로그인은 서로 독립적으로 선택한다.
                      Wrap(
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          InkWell(
                            onTap: _vm.toggleRememberMe,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _vm.isRememberMe,
                                    activeColor: AppColors.slate,
                                    onChanged: (value) =>
                                        _vm.setRememberMe(value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '사번 저장',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _vm.toggleAutoLogin,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _vm.isAutoLoginEnabled,
                                    activeColor: AppColors.slate,
                                    onChanged: (value) =>
                                        _vm.setAutoLoginEnabled(value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '자동 로그인',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: AppColors.slate,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_vm.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _vm.errorMessage!,
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
                          onPressed: _vm.isLoading ? null : _handleLogin,
                          child: _vm.isLoading
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