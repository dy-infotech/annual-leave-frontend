import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_drawer.dart';
import '../viewmodel/profile_viewmodel.dart';

class MyInfoScreen extends StatefulWidget {
  const MyInfoScreen({super.key});

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();

  bool isEditingEmail = false;
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final success = await context.read<ProfileViewModel>().changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      newPasswordConfirm: _newPasswordConfirmController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _newPasswordConfirmController.clear();
    }
  }

  Future<void> _handleChangeEmail() async {
    final success = await context.read<ProfileViewModel>().changeEmail(_emailController.text);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일이 변경되었습니다.')));
      _emailController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>();
    final info = profile.employeeInfo;
    final usedLeaveDays = info != null ? info.currTotalLeaveDays - info.remainingLeaveDays : null;

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('기본 정보', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                      '${usedLeaveDays?.toString() ?? '-'} / ${info?.currTotalLeaveDays.toString() ?? '-'}',
                    ),
                  ),
                  const _InfoDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                    child: SizedBox(
                      height: 36,
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
                                      cursorHeight: 18,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    )
                                  : Text(info?.email ?? '-', style: const TextStyle(fontSize: 16)),
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
                              setState(() => isEditingEmail = !isEditingEmail);
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
                  if (profile.emailError != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        profile.emailError!,
                        style: const TextStyle(color: AppColors.coral, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                  if (profile.passwordError != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        profile.passwordError!,
                        style: const TextStyle(color: AppColors.coral, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: profile.isChangingPassword ? null : _handleChangePassword,
                      child: profile.isChangingPassword
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
  final Widget value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: value),
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
