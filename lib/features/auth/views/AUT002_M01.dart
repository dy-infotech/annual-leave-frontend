// AUT002_M01: 사용자 등록(회원가입) 화면
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:annual_leave_frontend/features/auth/view_models/AUT002_M01_view_model.dart';
import 'package:provider/provider.dart';
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

class SignupScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final AuthRepository? repository;

  const SignupScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupViewModel(repository: repository),
      child: const _SignupView(),
    );
  }
}

class _SignupView extends StatefulWidget {
  const _SignupView();

  @override
  State<_SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<_SignupView> {
  SignupViewModel get _vm => context.read<SignupViewModel>();

  Future<void> _handleSignup() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.signUp();
    if (ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('사용 등록이 완료되었습니다. 로그인해 주세요.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SignupViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('사용 등록')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '관리자가 등록해둔 사번으로\n가입할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                // const SizedBox(height: 32),
                // TextField(
                //   controller: _vm.employeeNumberController,
                //   decoration: const InputDecoration(labelText: '사번'),
                //   keyboardType: TextInputType.text,
                //   textCapitalization: TextCapitalization.characters,
                // ),
                const SizedBox(height: 32),
                TextField(
                  controller: _vm.employeeNumberController,
                  decoration: const InputDecoration(labelText: '사번'),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  // 영문/숫자 제한 및 실시간 대문자 변환 포매터 주입
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9]')), // 영문 및 숫자만 허용
                    UpperCaseTextFormatter(), // 소문자 입력 시 대문자로 강제 변환
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: _vm.passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vm.passwordConfirmController,
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  obscureText: true,
                  onSubmitted: (_) => _handleSignup(),
                ),
                if (_vm.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _vm.isLoading ? null : _handleSignup,
                    child: _vm.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('등록하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}