import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_utils.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _employeeNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignup() async {
    if (_employeeNumberController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = '사번과 비밀번호를 입력해 주세요.');
      return;
    }
    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() => _errorMessage = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().signUp(
        _employeeNumberController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용 등록이 완료되었습니다. 로그인해 주세요.')),
        );
        Navigator.pop(context);
      }
    } catch (e, s) {
      logError('SignupScreen._handleSignup', e, s);
      if (mounted) {
        setState(() => _errorMessage = messageFromError(e,
            fallback: '등록되지 않은 사번이거나 이미 가입된 사번입니다.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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