import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/models/employee.dart';
import 'package:annual_leave_frontend/models/auth_models.dart';
import 'package:annual_leave_frontend/models/enums/RoleType.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/registe_status_badge.dart';
import '../widgets/date_input_dialog.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({
    super.key,
    required this.employee,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  bool _isEditing = false; // 현재 수정 모드 여부
  bool _isSaving = false; // 저장 API 호출 중 로딩 상태
  bool _isLoadingCommon = true; // 기초 데이터 로딩 상태

  final _formKey = GlobalKey<FormState>();

  // 컨트롤러 선언
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _hireDateController;
  late TextEditingController _fireDateController;
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

  // 🎯 날짜 처리를 위한 상태 변수 균형 맞춤
  DateTime? _selectedHireDate; // 입사일 전용 변수 (기존 양식 명칭 유지)
  DateTime? _selectedFireDate; // ⭕ 퇴사일 전용 독립 상태 변수 객체 추가
  String? _formatDate;

  RoleType? _selectedManagerYn = RoleType.employee; //선택된 관리자여부
  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.employee.name);
    _emailController = TextEditingController(text: widget.employee.email ?? '');

    // 입사일 컨트롤러 초기화 및 0패딩 보장
    _hireDateController = TextEditingController(
      text: widget.employee.hireDate != null &&
              widget.employee.hireDate!.isNotEmpty
          ? DateFormat('yyyy.MM.dd').format(DateTime.parse(
              widget.employee.hireDate!.contains('T')
                  ? widget.employee.hireDate!.split('T')[0]
                  : widget.employee.hireDate!))
          : '',
    );

    // 2페이지 71라인 부근 원본 코드
    _fireDateController = TextEditingController(
      text: widget.employee.fireDate != null &&
              widget.employee.fireDate!.isNotEmpty
          ? DateFormat('yyyy.MM.dd').format(DateTime.parse(
              widget.employee.fireDate!.contains('T')
                  ? widget.employee.fireDate!.split('T')[0]
                  : widget.employee.fireDate!))
          : '',
    );

    _passwordController = TextEditingController();
    _otherTeamController = TextEditingController();

    _selectedDepartment = widget.employee.department;
    _selectedPosition = widget.employee.position;
    _selectedTeam = widget.employee.team;
    _selectedRole = (widget.employee.role == 'ADMIN') ? '관리자' : '멤버';

    // 🎯 기존 입사일 파싱 양식 및 변수명 원본 유지
    if (widget.employee.hireDate != null) {
      try {
        String rawHire = widget.employee.hireDate!.trim();
        String cleanHire =
            rawHire.contains('T') ? rawHire.split('T')[0] : rawHire;
        if (cleanHire.length == 4) cleanHire = '$cleanHire-01-01';

        _selectedHireDate = DateTime.parse(cleanHire);
        _formatDate = widget.employee.hireDate;
      } catch (_) {}
    }

    // 🎯 퇴사일도 완벽히 대칭되는 형태로 문법 오류를 방어하여 상태 누적
    if (widget.employee.fireDate != null) {
      try {
        String rawFire = widget.employee.fireDate!.trim();
        String cleanFire =
            rawFire.contains('T') ? rawFire.split('T')[0] : rawFire;
        if (cleanFire.length == 4) cleanFire = '$cleanFire-01-01';

        _selectedFireDate = DateTime.parse(cleanFire);
      } catch (_) {}
    }

    //context.read<AuthProvider>().fetchMyInfo();
    _fetchCommonData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _hireDateController.dispose();
    _fireDateController.dispose(); // 🎯 퇴사일 컨트롤러 누락되었던 메모리 자원 해제 추가
    _passwordController.dispose();
    _otherTeamController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommonData() async {
    setState(() => _isLoadingCommon = true);
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;

      final List<String> fetchedDepartments =
          List<String>.from(data['department'] ?? []);
      final List<String> fetchedPositions =
          List<String>.from(data['position'] ?? []);
      final dynamic rawTeamData = data['accessibleTeam'] ?? data['team'] ?? [];
      final List<String> fetchedTeams = [];

      if (rawTeamData is List) {
        for (var item in rawTeamData) {
          if (item is String) {
            fetchedTeams.add(item);
          } else if (item is Map) {
            final String? nameFromTable =
                item['teamName']?.toString() ?? item['name']?.toString();
            if (nameFromTable != null) fetchedTeams.add(nameFromTable);
          }
        }
      }

      setState(() {
        _departmentList.clear();
        _teamList.clear();
        _positionList.clear();

        _departmentList.addAll(fetchedDepartments);
        _teamList.addAll(fetchedTeams);
        _positionList.addAll(fetchedPositions);

        // 🎯 덮어쓰기 버그 예방: 이미 선택된 팀이 존재할 경우 리셋 연산 방어
        if (_selectedTeam == null || !_teamList.contains(_selectedTeam)) {
          String? originalTeam = widget.employee.team;
          if (originalTeam != null && originalTeam.isNotEmpty) {
            if (_teamList.contains(originalTeam)) {
              _selectedTeam = originalTeam;
            } else {
              _teamList.add(originalTeam);
              _selectedTeam = originalTeam;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('🚨 DB 공통 코드 로딩 중 에러 발생: $e');
    } finally {
      setState(() => _isLoadingCommon = false);
    }
  }

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

  // 💾 서버 저장 처리 (200 OK 수신 및 화면 고정 완전체)
  Future<void> _saveChanges() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      print('❌ [Form 검증 실패] 올바르지 않은 값이 존재합니다.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String roleCode = (_selectedRole == '관리자') ? 'ADMIN' : 'EMPLOYEE';
      String finalTeam = _selectedTeam ?? '';

      String formattedHireDate =
          _hireDateController.text.trim().replaceAll('.', '-');
      String formattedFireDate =
          _fireDateController.text.trim().replaceAll('.', '-');

      print(
          '🚀 [API 전송 시작] hireDate: "$formattedHireDate", fireDate: "$formattedFireDate"');

      final response = // 💾 _saveChanges() 함수 내부의 API 전송 객체 영역 최종 방어벽 구축
          // 💾 _saveChanges() 함수 내부의 API 전송 객체 영역 최종 덮어쓰기
          await ApiClient().dio.put(
        '/api/admin/employees/${widget.employee.employeeNumber}',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text.trim(),
          'department': _selectedDepartment,
          'team': finalTeam,
          'position': _selectedPosition,
          'role': roleCode,

          'hireDate':
              formattedHireDate.isNotEmpty && formattedHireDate.length == 10
                  ? formattedHireDate
                  : null,

// TO-BE (수정 후)
          'fireDate':
              formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                  ? formattedFireDate
                  : null, // 👈 백엔드로 null을 정직하게 보냅니다.
          'firedDate':
              formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                  ? formattedFireDate
                  : null, // 👈 대칭되는 필드도 함께 null 처리합니다.

          'currTotalLeaveDays': widget.employee.currTotalLeaveDays,
          'targetTeamForRoleSwap':
              (_selectedRole == '관리자' || _selectedManagerYn == RoleType.admin)
                  ? (_selectedTeam ?? '')
                  : '',
        },
      );

      // 본문이 null 이어도 상태코드가 성공이면 화면 락 갱신 보장
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사원 정보가 성공적으로 수정되었습니다.')),
          );

          setState(() {
            _isEditing = false; // 읽기 전용 폼 잠금 활성화
            _passwordController.clear();

            // 🎯 저장 완료 후 컨트롤러 데이터를 강제로 유지시켜 즉시 조회 보장
            _nameController.text = _nameController.text.trim();
            _emailController.text = _emailController.text.trim();
            _hireDateController.text = _hireDateController.text.trim();
            _fireDateController.text =
                _fireDateController.text.trim(); // ⭕ 퇴사일 보존

            _selectedDepartment = _selectedDepartment;
            _selectedTeam = _selectedTeam;
            _selectedPosition = _selectedPosition;
          });
        }
      }
    } catch (e) {
      print('❌ [API 호출 에러]: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

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
                                  fillColor: _isEditing
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
                                    '잔여 : ${widget.employee.remainingLeaveDays}일 / 올해 : ${widget.employee.currTotalLeaveDays}일',
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
                              )),

                          _buildRow(
                              '사용자명',
                              TextFormField(
                                controller: _nameController,
                                readOnly: !_isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: (_isEditing &&
                                          authProvider.employeeInfo?.position ==
                                              '사장')
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: (_isEditing &&
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
                                controller: _emailController,
                                readOnly: !_isEditing,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: _isEditing
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: _isEditing
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
                              _isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장'
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
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),
                          // 6. 팀 선택 드롭다운 영역 교체
                          _buildRow(
                              '팀',
                              (_isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장')
                                  ? DropdownButtonFormField<String>(
                                      value: (_selectedTeam != '기타' &&
                                              _teamList.contains(_selectedTeam))
                                          ? _selectedTeam
                                          : null,
                                      items: _teamList
                                          .where((t) => t != '기타')
                                          .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: (val) =>
                                          setState(() => _selectedTeam = val),
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
                                                  horizontal: 12,
                                                  vertical: 12)),
                                    )),

                          _buildRow(
                            '직급',
                            // 편집 모드이고, 현재 선택된 직급이 '사장'일 때만 Dropdown 표시
                            (_isEditing &&
                                    authProvider.employeeInfo?.position ==
                                        '사장' &&
                                    widget.employee.position != '사장')
                                ? DropdownButtonFormField<String>(
                                    value: _positionList
                                            .contains(_selectedPosition)
                                        ? _selectedPosition
                                        : null,
                                    items: _positionList
                                        .map((d) => DropdownMenuItem(
                                            value: d,
                                            child: Text(d,
                                                style: const TextStyle(
                                                    color: Colors.black))))
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedPosition = val),
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
                                                horizontal: 12, vertical: 12)),
                                  ),
                          ),

                          // 9. 입사일 영역 (수정 모드 잠금 완전 결함 해결판)
                          _buildRow(
                              '입사일',
                              (_isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장')
                                  ? TextFormField(
                                      controller: _hireDateController,
                                      readOnly: true,
                                      onTap: () => _selectDateForController(
                                        controller: _hireDateController,
                                        initialDate:
                                            _selectedHireDate ?? DateTime.now(),
                                        onDateSelected: (picked) =>
                                            _selectedHireDate = picked,
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
                                            controller: _hireDateController,
                                            initialDate: _selectedHireDate ??
                                                DateTime.now(),
                                            onDateSelected: (picked) =>
                                                _selectedHireDate = picked,
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
                                          _hireDateController, // ⭕ 읽기 모드 상시 매핑 유지
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
                                    fillColor: _isEditing
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
                              (_isEditing &&
                                      authProvider.employeeInfo?.position ==
                                          '사장' &&
                                      widget.employee.position != '사장')
                                  ? TextFormField(
                                      controller:
                                          _fireDateController, // ⭕ 수정 모드 매핑
                                      readOnly: true,
                                      onTap: () => _selectDateForController(
                                        controller: _fireDateController,
                                        initialDate:
                                            _selectedFireDate ?? DateTime.now(),
                                        onDateSelected: (picked) {
                                          setState(() {
                                            _selectedFireDate = picked;
                                            _fireDateController.text =
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
                                            controller: _fireDateController,
                                            initialDate: _selectedFireDate ??
                                                DateTime.now(),
                                            onDateSelected: (picked) {
                                              setState(() {
                                                _selectedFireDate = picked;
                                                _fireDateController.text =
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
                                          _fireDateController, // 🎯 [핵심] 읽기 모드에도 컨트롤러를 명확히 선언해 주어 화면 고정 조회를 연동합니다.
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
