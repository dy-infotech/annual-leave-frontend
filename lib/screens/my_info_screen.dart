import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _emailErrorMessage;

  bool isEditingEmail = false;
  final TextEditingController _emailController  = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _newPasswordConfirmController.text.isEmpty) {
      setState(() => _errorMessage = '모든 항목을 입력해주세요.');
      return;
    }
    if (_newPasswordController.text != _newPasswordConfirmController.text) {
      setState(() => _errorMessage = '새 비밀번호가 일치하지 않습니다.');
      return;
    }
    if (_newPasswordController.text == _currentPasswordController.text) {
      setState(() => _errorMessage = '현재 비밀번호와 다른 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiClient().dio.patch(
        '/api/employees/me/password',
        data: {
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _newPasswordConfirmController.clear();
      }
    } catch (e) {
      setState(() => _errorMessage = '현재 비밀번호가 일치하지 않거나 변경에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleChangeEmail() async {
    if (_emailController.text.isEmpty) {
      setState(() => _emailErrorMessage = '이메일 정보를 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _emailErrorMessage = null;
    });

    try {
      await ApiClient().dio.patch(
        '/api/employees/me/modify-email',
        data: _emailController.text
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일이 변경되었습니다.')));
        //AuthProvider.updateEmail();
        context.read<AuthProvider>().updateEmail(_emailController.text);

        _emailController.clear();
      }
    } catch (e) {
      setState(() => _emailErrorMessage = '이메일 변경에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = context.watch<AuthProvider>().employeeInfo;
    final dashboard = context.watch<DashboardProvider>();
    
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 기본 정보 (읽기 전용)
            const Text(
              '기본 정보',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _InfoRow(label: '사번', value: Text(info?.employeeNumber ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '이름', value: Text(info?.name ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '직급', value: Text(info?.position ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '부서', value: Text(info?.department ?? '-')),
                  if (info?.hireDate != null) ...[
                    const _InfoDivider(),
                    _InfoRow(label: '입사일', value: Text(info!.hireDate!)),
                  ],
                  const _InfoDivider(),
                  _InfoRow(
                    label: '연차정보',
                    value: Text(
                      '${dashboard.data?.myLeaveInfo.remainingLeaveDays?.toString() ?? '-'} / ${dashboard.data?.myLeaveInfo.totalLeaveDays?.toString() ?? '-'} 일',
                    ),
                  ),
                  const _InfoDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                    child: SizedBox(
                      height: 36,  // 좀 더 여유 있는 높이로 조절 추천
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: '이메일',
                              value: isEditingEmail
                                  ? TextField(
                                      controller: _emailController,
                                      style: const TextStyle(fontSize: 16),
                                      cursorHeight: 18, // 폰트 크기와 비슷하거나 조금 더 크게
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    )
                                  : Text(
                                      info?.email ?? '-',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              fixedSize: const Size(50, 50),
                              side: const BorderSide(color: Colors.grey, width: 1),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () async {
                              if (isEditingEmail) {
                                await _handleChangeEmail();
                              }
                              setState(() {
                                isEditingEmail = !isEditingEmail;
                              });
                            },
                            child: Icon(
                              isEditingEmail ? Icons.check : Icons.edit,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_emailErrorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _emailErrorMessage!,
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 비밀번호 변경 (수정 가능)
            const Text(
              '비밀번호 변경',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '현재 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '새 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                    onSubmitted: (_) => _handleChangePassword(),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.coral,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleChangePassword,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('비밀번호 변경'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget value;  // Widget 타입 유지

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: value,  // 이미 위젯이니까 그대로 넣기
        ),
      ],
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}
