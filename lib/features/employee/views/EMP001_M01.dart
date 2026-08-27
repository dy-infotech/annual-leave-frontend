// EMP001_M01: 내 정보 화면
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/features/employee/repositories/employee_repository.dart';
import 'package:annual_leave_frontend/features/employee/view_models/EMP001_M01_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import '../widgets/email_autocomplete_field.dart';

class MyInfoScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final EmployeeRepository? repository;

  const MyInfoScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyInfoViewModel(
        authProvider: context.read<AuthProvider>(),
        repository: repository,
      ),
      child: const _MyInfoView(),
    );
  }
}

class _MyInfoView extends StatefulWidget {
  const _MyInfoView();

  @override
  State<_MyInfoView> createState() => _MyInfoViewState();
}

class _MyInfoViewState extends State<_MyInfoView> {
  MyInfoViewModel get _vm => context.read<MyInfoViewModel>();

  Future<void> _handleChangePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.changePassword();
    if (ok && mounted) {
      messenger
          .showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));
    }
  }

  Future<bool> _handleChangeEmail() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.changeEmail();
    if (ok && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('이메일이 변경되었습니다.')));
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<MyInfoViewModel>();
    final info = context.watch<AuthProvider>().employeeInfo;

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
                  _InfoRow(
                      label: '사번', value: Text(info?.employeeNumber ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '이름', value: Text(info?.name ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '직급', value: Text(info?.position ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '부서', value: Text(info?.department ?? '-')),
                  const _InfoDivider(),
                  _InfoRow(label: '소속팀', value: Text(info?.team ?? '-')),
                  if (info?.hireDate != null) ...[
                    const _InfoDivider(),
                    _InfoRow(label: '입사일', value: Text(info!.hireDate!)),
                  ],
                  const _InfoDivider(),
                  _InfoRow(
                    label: '연차정보',
                    value: Text(
                      '${info?.remainingLeaveDays.toString() ?? '-'} / ${info?.currTotalLeaveDays.toString() ?? '-'} 일',
                    ),
                  ),
                  const _InfoDivider(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                    child: SizedBox(
                      height: 36, // 좀 더 여유 있는 높이로 조절 추천
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _InfoRow(
                              label: '이메일',
                              value: _vm.isEditingEmail
                                  ? EmailAutocompleteField(
                                      controller: _vm.emailController,
                                      onSubmitted: () async {
                                        await _handleChangeEmail();
                                      },
                                    )
                                  : Text(
                                      info?.email ?? '-',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(50, 50),
                              maximumSize: const Size(60, 50),
                              side: const BorderSide(
                                  color: Colors.grey, width: 1),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () async {
                              if (_vm.isEditingEmail) {
                                await _handleChangeEmail();
                              } else {
                                _vm.startEditingEmail();
                              }
                            },
                            child: Icon(
                              _vm.isEditingEmail ? Icons.check : Icons.edit,
                              size: 20,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_vm.emailErrorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _vm.emailErrorMessage!,
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
                    controller: _vm.currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '현재 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vm.newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '새 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _vm.newPasswordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                    onSubmitted: (_) => _handleChangePassword(),
                  ),
                  if (_vm.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _vm.errorMessage!,
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
                      onPressed: _vm.isSubmitting ? null : _handleChangePassword,
                      child: _vm.isSubmitting
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
  final Widget value; // Widget 타입 유지

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
          child: value, // 이미 위젯이니까 그대로 넣기
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