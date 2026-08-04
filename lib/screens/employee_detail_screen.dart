import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/models/employee.dart';
import 'package:annual_leave_frontend/models/enums/RoleType.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/registe_status_badge.dart';
import '../widgets/date_input_dialog.dart';

import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/employee.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  bool _isEditing = false; // 현재 수정 모드 여부
  bool _isSaving = false; // 저장 API 호출 중 로딩 상태
  bool _isLoadingCommon = false; // 기초 데이터 로딩 상태

  final _formKey = GlobalKey<FormState>();

  // 컨트롤러 선언
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _hireDateController;
  late TextEditingController _passwordController;
  late TextEditingController _otherTeamController; // 기타 팀 선택 시 입력 컨트롤러

  // 등록 화면과 매칭되는 공통 기초 데이터 리스트 및 선택 상태 변수
  final List<String> _departmentList = [];
  final List<String> _teamList = [];
  final List<String> _positionList = [];

  String? _selectedDepartment;
  String? _selectedTeam;
  String? _selectedPosition;
  String? _selectedRole; // 💡 권한 타입 상태 변수 (ADMIN / EMPLOYEE 등 변환 타겟)
  DateTime? _selectedDate;
  String? _formatDate;

  RoleType? _selectedManagerYn = RoleType.employee; //선택된 관리자여부

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email ?? '');
    _hireDateController =
        TextEditingController(text: widget.employee.hireDate ?? '');
    _passwordController = TextEditingController();
    _otherTeamController = TextEditingController();

    _selectedDepartment = widget.employee.department;
    _selectedPosition = widget.employee.position;

    // 💡 초기 진입 시점에 모델의 원본 팀 데이터를 무조건 먼저 대입합니다.
    _selectedTeam = widget.employee.team;

    _selectedRole = (widget.employee.role == 'ADMIN') ? '관리자' : '맴버';

    if (widget.employee.hireDate != null) {
      try {
        _selectedDate = DateTime.parse(widget.employee.hireDate!);
        _formatDate = widget.employee.hireDate;
      } catch (_) {}
    }

    _fetchCommonData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _hireDateController.dispose();
    _passwordController.dispose();
    _otherTeamController.dispose();
    super.dispose();
  }

  // 사원등록화면(SignupManageScreen)과 동일한 공통 기초데이터 로드 함수
  // 📄 1페이지 내의 기존 함수를 아래 코드로 대체하세요.
  Future<void> _fetchCommonData() async {
    setState(() => _isLoadingCommon = true);
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;

      // 1. 기초 리스트 데이터를 먼저 완전히 파싱하여 채워 넣습니다.
      final List<String> fetchedDepartments =
          List<String>.from(data['department']);
      final List<String> fetchedTeams = List<String>.from(data['team']);
      final List<String> fetchedPositions = List<String>.from(data['position']);

      setState(() {
        _departmentList.clear();
        _teamList.clear();
        _positionList.clear();

        _departmentList.addAll(fetchedDepartments);
        _teamList.addAll(fetchedTeams);
        _positionList.addAll(fetchedPositions);

        if (!_teamList.contains('기타')) {
          _teamList.add('기타');
        }

        // 2. 💡 원본 데이터 보존을 위해 가져온 리스트에 실제 존재하는지 "먼저" 완벽히 대조합니다.
        // widget.employee.team의 원래 값을 백업하여 검증합니다.
        String? originalTeam = widget.employee.team;

        if (originalTeam != null && originalTeam.isNotEmpty) {
          if (_teamList.contains(originalTeam)) {
            // 가져온 서버 리스트에 팀명이 존재하면 그 값을 그대로 바인딩합니다.
            _selectedTeam = originalTeam;
          } else {
            // 진짜로 리스트에 없는 커스텀 팀명일 때만 '기타' 인풋을 활성화합니다.
            _otherTeamController.text = originalTeam;
            _selectedTeam = '기타';
          }
        }
      });
    } catch (_) {
      // 로딩 오류 예외 처리
    } finally {
      setState(() => _isLoadingCommon = false);
    }
  }

  // 커스텀 달력 모달 다이얼로그 호출
  Future<void> _selectDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => DateInputDialog(initialDate: _selectedDate),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _formatDate = DateFormat('yyyy.MM.dd').format(picked);
        _hireDateController.text =
            '${picked.year}년 ${picked.month}월 ${picked.day}일';
      });
    }
  }

  // 💾 서버 저장 처리
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String roleCode = (_selectedRole == '관리자') ? 'ADMIN' : 'EMPLOYEE';
      String finalTeam = (_selectedTeam == '기타')
          ? _otherTeamController.text.trim()
          : (_selectedTeam ?? '');

      // 1. 기존 사원 정보 업데이트 (Role에 따라 데이터 구조가 분기되거나 기본 수정 진행)
      await ApiClient().dio.put(
        '/api/admin/employees/${widget.employee.employeeNumber}',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text.trim(),
          'department': _selectedDepartment,
          'position': _selectedPosition,
          'role': roleCode,
          'hireDate': _hireDateController.text.trim(),
          'currTotalLeaveDays': widget.employee.currTotalLeaveDays,
        },
      );

      // // 2. 💡 역할 정보 변경 시 Team 테이블 반영을 위한 별도 API 호출 분기
      // // 예시: 관리자/멤버 역할에 따라 팀 테이블에 매핑 데이터를 삽입/수정하는 API
      // await ApiClient().dio.post(
      //   '/api/admin/teams/assign-role',
      //   data: {
      //     'employeeNumber': widget.employee.employeeNumber,
      //     'teamName': finalTeam,
      //     'role': roleCode, // 이 값에 의해 백엔드에서 team 테이블 insert/update 수행
      //   },
      // );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사원 정보가 성공적으로 수정되었습니다.')),
        );
      }

      setState(() {
        _isEditing = false;
        _passwordController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보 업데이트에 실패했습니다.')),
        );
      }
    }
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>().employeeInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 정보 상세'),
        actions: [
          _isSaving
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
                    if (_isEditing) {
                      _saveChanges();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  child: Text(
                    _isEditing ? '저장' : '수정',
                    style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: _isLoadingCommon
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // 2. 하단 상세 정보 관리 영역 카드
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface, // 상단 카드와 일치하는 배경
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '사용자 정보 관리',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 12),

                            // 1. 사번 (항상 수정 불가능 -> 연회색 고정 바탕 및 패딩 일치)
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
                                  fillColor: _isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),

                            // 2. 연차 정보 (항상 수정 불가능)
                            _buildRow(
                              '연차 정보',
                              TextFormField(
                                initialValue:
                                    '잔여 연차 : ${widget.employee.remainingLeaveDays}일 / 총 연차 : ${widget.employee.currTotalLeaveDays}일',
                                readOnly: true,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            // 3. 사용자명 정보 (수정 가능)
                            _buildRow(
                              '사용자명',
                              TextFormField(
                                controller: _nameController,
                                // _isEditing이 true일 때만 입력 가능
                                readOnly: !_isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  // 수정 중일 때는 흰색, 아닐 때는 회색 바탕
                                  fillColor: _isEditing
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  // 수정 중일 때는 기본 테두리 노출, 아닐 때는 테두리 숨김
                                  border: _isEditing
                                      ? const OutlineInputBorder()
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  // 포커스(클릭)되었을 때의 테두리 스타일 (필요시 색상 변경 가능)
                                  focusedBorder: _isEditing
                                      ? OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              width: 2))
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            // 4. 이메일 정보 (수정 가능)

                            _buildRow(
                              '사용자명',
                              TextFormField(
                                controller: _emailController,
                                // _isEditing이 true일 때만 입력 가능
                                readOnly: !_isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  // 수정 중일 때는 흰색, 아닐 때는 회색 바탕
                                  fillColor: _isEditing
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  // 수정 중일 때는 기본 테두리 노출, 아닐 때는 테두리 숨김
                                  border: _isEditing
                                      ? const OutlineInputBorder()
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  // 포커스(클릭)되었을 때의 테두리 스타일 (필요시 색상 변경 가능)
                                  focusedBorder: _isEditing
                                      ? OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              width: 2))
                                      : const OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                        ? '이메일 정보를 입력해 주세요.'
                                        : null,
                              ),
                            ),

                            // 5. 부서 (드롭다운과 인풋박스 외곽 사이즈 일치 정렬)
                            _buildRow(
                              '부서',
                              _isEditing
                                  ? DropdownButtonFormField<String>(
                                      value: _departmentList
                                              .contains(_selectedDepartment)
                                          ? _selectedDepartment
                                          : null,
                                      items: _departmentList
                                          .map((d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: (val) => setState(
                                          () => _selectedDepartment = val),
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder()),
                                      validator: (val) =>
                                          val == null ? '부서를 선택해 주세요.' : null,
                                    )
                                  : TextFormField(
                                      initialValue: _selectedDepartment ?? '-',
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
                                                horizontal: 12, vertical: 12),
                                      ),
                                    ),
                            ),
                            // 6. 팀
                            _buildRow(
                              '팀',
                              _isEditing
                                  ? DropdownButtonFormField<String>(
                                      value: _teamList.contains(_selectedTeam)
                                          ? _selectedTeam
                                          : null,
                                      items: _teamList
                                          .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: (val) => setState(() {
                                        _selectedTeam = val;
                                        if (val != '기타')
                                          _otherTeamController.clear();
                                      }),
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder()),
                                      validator: (val) =>
                                          val == null ? '팀을 선택해 주세요.' : null,
                                    )
                                  : TextFormField(
                                      initialValue: _selectedTeam ?? '-',
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
                                                horizontal: 12, vertical: 12),
                                      ),
                                    ),
                            ),

                            // 팀 '기타' 입력 영역
                            if (_isEditing && _selectedTeam == '기타') ...[
                              _buildRow(
                                '기타 팀명',
                                TextFormField(
                                  controller: _otherTeamController,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black),
                                  decoration: const InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      hintText: '새로운 팀명 입력'),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                          ? '팀명을 입력해 주세요.'
                                          : null,
                                ),
                              ),
                            ],

                            // 7. 직급
                            _buildRow(
                              '직급',
                              _isEditing
                                  ? DropdownButtonFormField<String>(
                                      value: _positionList
                                              .contains(_selectedPosition)
                                          ? _selectedPosition
                                          : null,
                                      items: _positionList
                                          .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: (val) => setState(
                                          () => _selectedPosition = val),
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          border: OutlineInputBorder()),
                                      validator: (val) =>
                                          val == null ? '직급을 선택해 주세요.' : null,
                                    )
                                  : TextFormField(
                                      initialValue: _selectedPosition ?? '-',
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
                                                horizontal: 12, vertical: 12),
                                      ),
                                    ),
                            ),

                            // 8. 관리자 여부 (항상 수정 불가능)
                            _buildRow(
                              '관리자 여부',
                              TextFormField(
                                initialValue: RoleType.employee.label,
                                readOnly: true,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.transparent)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),

                            // 9. 입사일 (기등록 회원일 경우 수정 불가 제어 및 크기 고정)
                            _buildRow(
                              '입사일',
                              _isEditing &&
                                      !(widget.employee.isRegisted ?? false)
                                  ? TextFormField(
                                      controller: _hireDateController,
                                      readOnly: true,
                                      onTap: _selectHireDate,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        suffixIcon: IconButton(
                                            icon: const Icon(
                                                Icons.calendar_month,
                                                size: 18),
                                            onPressed: _selectHireDate),
                                      ),
                                      validator: (val) =>
                                          val == null || val.trim().isEmpty
                                              ? '입사일 정보를 입력해 주세요.'
                                              : null,
                                    )
                                  : TextFormField(
                                      controller: _hireDateController,
                                      readOnly: true,
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor: _isEditing &&
                                                (widget.employee.isRegisted ??
                                                    false)
                                            ? Colors.grey.shade100
                                            : Colors.grey.shade50,
                                        border: const OutlineInputBorder(
                                            borderSide: BorderSide(
                                                color: Colors.transparent)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                      ),
                                    ),
                            ),

                            // 10. 등록일 (항상 수정 불가능)
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
                                  fillColor: _isEditing
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                                  border: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: Colors.transparent)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        )),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _selectHireDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        // yyyy-MM-dd 형식으로 텍스트창에 주입
        _hireDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // 공통 행 레이아웃 모듈 위젯
  Widget _buildRow(String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14))),
          Expanded(child: content),
        ],
      ),
    );
  }
}
