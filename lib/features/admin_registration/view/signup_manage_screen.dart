import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/dashboard/view/dashboard_screen.dart';
import '../../../core/network/api_client.dart';
import '../../profile/viewmodel/profile_viewmodel.dart';
import '../model/api_client/admin_registration_api_client.dart';
import '../model/enum/role_type.dart';
import '../viewmodel/admin_registration_viewmodel.dart';

class SignupManageScreen extends StatelessWidget {
  const SignupManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminRegistrationViewModel(AdminRegistrationApiClient(ApiClient()))..loadOptions(),
      child: const _SignupManageView(),
    );
  }
}

class _SignupManageView extends StatefulWidget {
  const _SignupManageView();

  @override
  State<_SignupManageView> createState() => _SignupManageViewState();
}

class _SignupManageViewState extends State<_SignupManageView> {
  final _employeeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _hireDateController = TextEditingController();
  DateTime? _selectedDate;

  String? _selectedTeam;
  String? _otherTeamName;
  String? _selectedDepartment;
  String? _selectedPosition;
  RoleType? _selectedRole = RoleType.employee;

  Future<void> _handleSignup() async {
    final vm = context.read<AdminRegistrationViewModel>();
    final team = _selectedTeam == '기타' ? (_otherTeamName ?? '') : (_selectedTeam ?? '');

    final success = await vm.register(
      name: _employeeNameController.text.trim(),
      department: _selectedDepartment ?? '',
      team: team,
      position: _selectedPosition ?? '',
      role: _selectedRole,
      email: _emailController.text.trim(),
      hireDate: _selectedDate,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 등록이 완료되었습니다. 사용 등록 후 로그인 가능합니다.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('ko'),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _hireDateController.text = '${picked.year}년 ${picked.month}월 ${picked.day}일';
      });
      context.read<AdminRegistrationViewModel>().clearFieldError('hireDate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminRegistrationViewModel>();
    final profile = context.watch<ProfileViewModel>();
    final info = profile.employeeInfo;
    final includeOtherOption = profile.isAdmin && info?.position == '대표이사';
    final teamOptions = vm.teamOptions(includeOtherOption: includeOtherOption);

    return Scaffold(
      appBar: AppBar(title: const Text('신규 사원 등록')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                TextField(
                  controller: _employeeNameController,
                  decoration: InputDecoration(
                    labelText: '사용자명',
                    errorText: vm.nameError,
                  ),
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  onChanged: (_) => vm.clearFieldError('name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '부서',
                    border: const OutlineInputBorder(),
                    errorText: vm.departmentError,
                  ),
                  initialValue: _selectedDepartment,
                  items: vm.departments
                      .map((dept) => DropdownMenuItem<String>(value: dept, child: Text(dept)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedDepartment = value);
                    vm.clearFieldError('department');
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '팀',
                    border: const OutlineInputBorder(),
                    errorText: vm.teamError,
                  ),
                  initialValue: _selectedTeam,
                  items: teamOptions
                      .map((team) => DropdownMenuItem<String>(value: team, child: Text(team)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTeam = value;
                      if (value != '기타') _otherTeamName = null;
                    });
                    vm.clearFieldError('team');
                  },
                ),
                if (_selectedTeam == '기타') ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '기타 팀명을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) => setState(() => _otherTeamName = text),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '직급',
                    border: const OutlineInputBorder(),
                    errorText: vm.positionError,
                  ),
                  initialValue: _selectedPosition,
                  items: vm.positions
                      .map((pos) => DropdownMenuItem<String>(value: pos, child: Text(pos)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedPosition = value);
                    vm.clearFieldError('position');
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoleType>(
                  decoration: const InputDecoration(
                    labelText: '역할 선택',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: _selectedRole,
                  items: RoleType.values
                      .map((role) => DropdownMenuItem<RoleType>(value: role, child: Text(role.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedRole = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: '이메일', errorText: vm.emailError),
                  obscureText: false,
                  onChanged: (_) => vm.clearFieldError('email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hireDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: '입사일',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                    errorText: vm.hireDateError,
                  ),
                  onTap: _selectDate,
                ),
                if (vm.loadError != null) ...[
                  const SizedBox(height: 12),
                  Text(vm.loadError!, style: const TextStyle(color: Colors.red)),
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
