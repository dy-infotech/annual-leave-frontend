// ADM004_D01: 사원 상세 화면 (ADM004_M01에서 진입)
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:intl/intl.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/admin/view_models/ADM004_D01_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import '../widgets/registe_status_badge.dart';
import '../widgets/date_input_dialog.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final Employee employee;

  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final AdminEmployeeRepository? repository;
  final CommonCodeRepository? commonCodeRepository;

  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    this.repository,
    this.commonCodeRepository,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmployeeDetailViewModel(
        employee: employee,
        repository: repository,
        commonCodeRepository: commonCodeRepository,
      )..fetchCommonData(),
      child: _EmployeeDetailView(employee: employee),
    );
  }
}

class _EmployeeDetailView extends StatefulWidget {
  final Employee employee;

  const _EmployeeDetailView({required this.employee});

  @override
  State<_EmployeeDetailView> createState() => _EmployeeDetailViewState();
}

class _EmployeeDetailViewState extends State<_EmployeeDetailView> {
  final _formKey = GlobalKey<FormState>();

  EmployeeDetailViewModel get _vm => context.read<EmployeeDetailViewModel>();

  // 📆 날짜 자릿수 정형화 공통 위젯 모달 팝업 함수
  Future<void> _selectDateForController({
    required TextEditingController controller,
    required DateTime initialDate,
    required Function(DateTime) onDateSelected,
  }) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => DateInputDialog(initialDate: initialDate),
    );

    if (picked != null && mounted) {
      setState(() {
        // 🎯 월/일이 한 자리수일 때 앞에 0을 강제 동기화 (무조건 10자 충족)
        controller.text = DateFormat('yyyy.MM.dd').format(picked);
        onDateSelected(picked);
      });
    }
  }

  // 💾 서버 저장 처리 (폼 검증 후 ViewModel에 위임)
  Future<void> _saveChanges() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      print('❌ [Form 검증 실패] 올바르지 않은 값이 존재합니다.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final saved = await _vm.saveChanges();
    if (saved && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('사원 정보가 성공적으로 수정되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<EmployeeDetailViewModel>();
    final authProvider = Provider.of<AuthSession>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 정보 상세'),
        actions: [
          _vm.isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))),
                )
              : TextButton(
                  onPressed: () {
                    if (_vm.isEditing) {
                      _saveChanges();
                    } else {
                      _vm.setEditing(true);
                    }
                  },
                  child: Text(
                    _vm.isEditing ? '저장' : '수정',
                    style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: _vm.isLoadingCommon
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('사용자 정보 관리',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                          const SizedBox(height: 24),

                          _buildRow(
                              '사번',
                              TextFormField(
                                initialValue: widget.employee.employeeNumber,
                                readOnly: true,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _vm.isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              )),

                          _buildRow(
                              '연차 정보',
                              TextFormField(
                                initialValue:
                                    '연차 : ${widget.employee.remainingLeaveDays}일 / 연차 : ${widget.employee.currTotalLeaveDays}일',
                                readOnly: true,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _vm.isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              )),

                          _buildRow(
                              '사용자명',
                              TextFormField(
                                controller: _vm.nameController,
                                readOnly: !_vm.isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: (_vm.isEditing &&
                                          authProvider.employeeInfo?.position ==
                                              '사장')
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: (_vm.isEditing &&
                                          authProvider.employeeInfo?.position ==
                                              '사장')
                                      ? const OutlineInputBorder()
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              )),

                          _buildRow(
                              '이메일',
                              TextFormField(
                                controller: _vm.emailController,
                                readOnly: !_vm.isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _vm.isEditing
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: _vm.isEditing
                                      ? const OutlineInputBorder()
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? '이메일 정보를 입력해 주세요.'
                                        : null,
                              )),

                          _buildRow(
                              '부서',
                              _vm.isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장'
                                  ? DropdownButtonFormField<String>(
                                      value: _vm.departmentList
                                              .contains(_vm.selectedDepartment)
                                          ? _vm.selectedDepartment
                                          : null,
                                      items: _vm.departmentList
                                          .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: _vm.selectDepartment,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder()),
                                      validator: (val) =>
                                          val == null ? '부서를 선택해 주세요.' : null,
                                    )
                                  : TextFormField(
                                      initialValue: _vm.selectedDepartment ?? '-',
                                      readOnly: true,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: const OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.transparent)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),
                          // 6. 팀 선택 드롭다운 영역 교체
                          _buildRow(
                              '팀',
                              (_vm.isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장')
                                  ? DropdownButtonFormField<String>(
                                      value: (_vm.selectedTeam != '기타' &&
                                              _vm.teamList.contains(_vm.selectedTeam))
                                          ? _vm.selectedTeam
                                          : null,
                                      items: _vm.teamList
                                          .where((t) => t != '기타')
                                          .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: _vm.selectTeam,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder()),
                                      validator: (val) =>
                                          val == null ? '팀을 선택해 주세요.' : null,
                                    )
                                  : TextFormField(
                                      initialValue: _vm.selectedTeam ?? '-',
                                      readOnly: true,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: const OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.transparent)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),

                          _buildRow(
                            '직급',
                            // 편집 모드이고, 현재 선택된 직급이 '사장'일 때만 Dropdown 표시
                            (_vm.isEditing &&
                                    authProvider.employeeInfo?.position ==
                                        '사장' &&
                                    widget.employee.position != '사장')
                                ? DropdownButtonFormField<String>(
                                    value: _vm.positionList
                                            .contains(_vm.selectedPosition)
                                        ? _vm.selectedPosition
                                        : null,
                                    items: _vm.positionList
                                        .map((d) => DropdownMenuItem(
                                            value: d,
                                            child: Text(d,
                                                style: const TextStyle(
                                                    color: Colors.black))))
                                        .toList(),
                                    onChanged: _vm.selectPosition,
                                    decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder()),
                                    validator: (val) =>
                                        val == null ? '직급을 선택해 주세요.' : null,
                                  )
                                : TextFormField(
                                    initialValue: _vm.selectedPosition ?? '-',
                                    readOnly: true,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black),
                                    decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        border: const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.transparent)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12)),
                                  ),
                          ),

                          // 9. 입사일 영역 (수정 모드 잠금 완전 결함 해결판)
                          _buildRow(
                              '입사일',
                              (_vm.isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장')
                                  ? TextFormField(
                                      controller: _vm.hireDateController,
                                      readOnly: true,
                                      onTap: () => _selectDateForController(
                                        controller: _vm.hireDateController,
                                        initialDate:
                                            _vm.selectedHireDate ?? DateTime.now(),
                                        onDateSelected: (picked) =>
                                            _vm.selectedHireDate = picked,
                                      ),
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.calendar_month,
                                              size: 18),
                                          onPressed: () =>
                                              _selectDateForController(
                                            controller: _vm.hireDateController,
                                            initialDate: _vm.selectedHireDate ??
                                                DateTime.now(),
                                            onDateSelected: (picked) =>
                                                _vm.selectedHireDate = picked,
                                          ),
                                        ),
                                      ),
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? '입사일 정보를 입력해 주세요.'
                                              : null,
                                    )
                                  : TextFormField(
                                      controller:
                                          _vm.hireDateController, // ⭕ 읽기 모드 상시 매핑 유지
                                      readOnly: true,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: const OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.transparent)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),

                          _buildRow(
                              '상태',
                              Wrap(children: [
                                RegisteStatusBadge(
                                    status: widget.employee.isRegisted == true
                                        ? '등록'
                                        : '미등록')
                              ])),

                          _buildRow(
                              '등록일',
                              TextFormField(
                                initialValue: widget.employee.createdAt !=
                                            null &&
                                        widget.employee.createdAt!.isNotEmpty
                                    ? DateFormat('yyyy.MM.dd').format(
                                        DateTime.parse(
                                            widget.employee.createdAt!))
                                    : '-',
                                readOnly: true,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: _vm.isEditing
                                        ? Colors.grey.shade100
                                        : Colors.grey.shade50,
                                    border: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: Colors.transparent)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12)),
                              )),

                          // 12. 퇴사일 영역 (컨트롤러 매핑 완료 및 조회 공백 버그 원천 해결)
                          _buildRow(
                              '퇴사일',
                              (_vm.isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장')
                                  ? TextFormField(
                                      controller:
                                          _vm.fireDateController, // ⭕ 수정 모드 매핑
                                      readOnly: true,
                                      onTap: () => _selectDateForController(
                                        controller: _vm.fireDateController,
                                        initialDate:
                                            _vm.selectedFireDate ?? DateTime.now(),
                                        onDateSelected: (picked) {
                                          setState(() {
                                            _vm.selectedFireDate = picked;
                                            _vm.fireDateController.text =
                                                DateFormat('yyyy.MM.dd')
                                                    .format(picked);
                                          });
                                        },
                                      ),
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.calendar_month,
                                              size: 18),
                                          onPressed: () =>
                                              _selectDateForController(
                                            controller: _vm.fireDateController,
                                            initialDate: _vm.selectedFireDate ??
                                                DateTime.now(),
                                            onDateSelected: (picked) {
                                              setState(() {
                                                _vm.selectedFireDate = picked;
                                                _vm.fireDateController.text =
                                                    DateFormat('yyyy.MM.dd')
                                                        .format(picked);
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    )
                                  : TextFormField(
                                      controller:
                                          _vm.fireDateController, // 🎯 [핵심] 읽기 모드에도 컨트롤러를 명확히 선언해 주어 화면 고정 조회를 연동합니다.
                                      readOnly: true,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: const OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Colors.transparent)),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // 공통 행 레이아웃 모듈 위젯
  Widget _buildRow(String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14))),
          Expanded(child: content),
        ],
      ),
    );
  }
}