import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../theme/app_theme.dart';
import '../model/api_client/signup_api_client.dart';
import '../viewmodel/signup_viewmodel.dart';

// 이 화면에서만 쓰이는 ViewModel이라 main.dart 전역이 아니라 여기서
// ChangeNotifierProvider로 화면 전용(scoped) 생성한다.
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupViewModel(SignupApiClient(ApiClient())),
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
  final _employeeNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  Future<void> _handleSignup() async {
    final success = await context.read<SignupViewModel>().signUp(
      employeeNumber: _employeeNumberController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _passwordConfirmController.text,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용 등록이 완료되었습니다. 로그인해 주세요.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SignupViewModel>();

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
                const SizedBox(height: 32),
                TextField(
                  controller: _employeeNumberController,
                  decoration: const InputDecoration(labelText: '사번'),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordConfirmController,
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  obscureText: true,
                  onSubmitted: (_) => _handleSignup(),
                ),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: vm.isSubmitting ? null : _handleSignup,
                    child: vm.isSubmitting
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
