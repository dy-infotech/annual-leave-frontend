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
  bool _isLoadingCommon = true; // 기초 데이터 로딩 상태

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
    // _hireDateController =
    //     TextEditingController(text: widget.employee.hireDate ?? '');

    // ✅ initState 내부에서 안전하게 YYYY.MM.DD 포맷으로 초기화합니다.
    _hireDateController = TextEditingController(
      text: widget.employee.hireDate != null &&
              widget.employee.hireDate!.isNotEmpty
          ? DateFormat('yyyy.MM.dd')
              .format(DateTime.parse(widget.employee.hireDate!))
          : '',
    );

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

  Future<void> _fetchCommonData() async {
    setState(() => _isLoadingCommon = true);
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;

      // 1. 서버 API 응답에서 부서와 직급 데이터 추출
      final List<String> fetchedDepartments =
          List<String>.from(data['department'] ?? []);
      final List<String> fetchedPositions =
          List<String>.from(data['position'] ?? []);

      // 2. 💡 [하드코딩 제거] DB 테이블의 원본 데이터가 담긴 정확한 Key를 찾아 매핑합니다.
      // 서버 응답 로그를 확인하여 'accessibleTeam' 또는 'team' 중 테이블 데이터가 들어오는 키를 지정하세요.
      final dynamic rawTeamData = data['accessibleTeam'] ?? data['team'] ?? [];
      final List<String> fetchedTeams = [];

      if (rawTeamData is List) {
        for (var item in rawTeamData) {
          if (item is String) {
            // A. 서버가 단순 문자열 리스트로 줄 때 (["스마트팩토리구축사업 팀", "개발팀"])
            fetchedTeams.add(item);
          } else if (item is Map) {
            // B. 서버가 DB 테이블 레코드 객체로 줄 때 ([{"id": 1, "teamName": "스마트팩토리구축사업 팀"}])
            // 백엔드 엔티티/테이블의 실제 컬럼명(예: 'teamName' 또는 'name')에 맞게 수정하세요.
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
        _teamList.addAll(fetchedTeams); // 🔥 DB 테이블에서 가져온 순수 데이터만 주입
        _positionList.addAll(fetchedPositions);

        // 3. 현재 사원이 속한 팀 정보가 DB에서 가져온 리스트에 존재하는지 대조 및 선택
        String? originalTeam = widget.employee.team;
        if (originalTeam != null && originalTeam.isNotEmpty) {
          if (_teamList.contains(originalTeam)) {
            _selectedTeam = originalTeam;
          } else {
            // DB 테이블 리스트에 없는 임의의 값인 경우에만 예외적으로 리스트에 추가하여 에러를 방지합니다.
            _teamList.add(originalTeam);
            _selectedTeam = originalTeam;
          }
        }
      });
    } catch (e) {
      debugPrint('🚨 DB 공통 코드 로딩 중 에러 발생: $e');
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

      // ⚙️ 변경 후 (간결하게 수정)
      String finalTeam = _selectedTeam ?? '';

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
          'team': finalTeam, // 👈 'team' 키값에 finalTeam 변수가 잘 들어가 있는지 꼭 확인하세요!
          'position': _selectedPosition,
          'role': roleCode,
          'hireDate': _hireDateController.text.trim().replaceAll('.', '-'),

          'currTotalLeaveDays': widget.employee.currTotalLeaveDays,
          // 2. 🔥 [핵심 수정] 백엔드 DTO 스펙인 'targetTeamForRoleSwap' 키를 매핑합니다!
          // 사용자가 드롭다운에서 '관리자'를 선택했다면 현재 선택된 팀 이름을 실어 보내고, '멤버'를 선택했다면 빈 값을 보냅니다.
          'targetTeamForRoleSwap':
              (_selectedRole == '관리자' || _selectedManagerYn == RoleType.admin)
                  ? (_selectedTeam ?? '')
                  : '',
        },
      );

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
              // 상하 여백만 16으로 줄이고 좌우 여백은 기존과 유사하게 유지
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),

              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
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
                            const SizedBox(height: 24),

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
                              '이메일',
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
                                      // 만약 현재 값이 '기타'라면 드롭다운이 에러 나지 않도록 null 처리
                                      value: (_selectedTeam != '기타' &&
                                              _teamList.contains(_selectedTeam))
                                          ? _selectedTeam
                                          : null,
                                      // 💡 .where()를 사용하여 사용자가 '기타'를 선택 목록에서 보지 못하게 원천 차단
                                      items: _teamList
                                          .where((t) => t != '기타')
                                          .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t,
                                                  style: const TextStyle(
                                                      color: Colors.black))))
                                          .toList(),
                                      onChanged: (val) => setState(() {
                                        _selectedTeam = val;
                                        // '기타' 선택이 불가능하므로 관련 분기 및 클리어 이벤트 제거
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
                                      // 읽기 모드일 때는 원래 저장된 값(예: 기타 혹은 기존 팀명)을 그대로 보여줍니다.
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

                            // 7. 직급 드롭다운 로우 (기타 팀명 조건문 아래로 명확히 분리)
                            _buildRow(
                              '직급',
                              _isEditing
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
                              // 💡 수정 모드이면서 로그인한 유저의 직급이 '대표' 또는 '사장'일 때만 드롭다운 전환
                              (_isEditing &&
                                      (context
                                                  .read<AuthProvider>()
                                                  .employeeInfo
                                                  ?.position ==
                                              "대표" ||
                                          context
                                                  .read<AuthProvider>()
                                                  .employeeInfo
                                                  ?.position ==
                                              "사장"))
                                  ? DropdownButtonFormField<RoleType>(
                                      // 🔥 [수정] value에 한글 문자열 대신 이넘 상태 변수인 _selectedManagerYn을 직접 주입합니다.
                                      value: _selectedManagerYn ??
                                          (widget.employee.role == 'ADMIN'
                                              ? RoleType.admin
                                              : RoleType.employee),

                                      // 🔥 [수정] items 목록도 RoleType 이넘 배열 데이터를 순회하며 정확히 매핑합니다.
                                      items:
                                          RoleType.values.map((RoleType role) {
                                        return DropdownMenuItem<RoleType>(
                                          value: role,
                                          child: Text(
                                            role.label, // 화면에는 '관리자' 또는 '멤버' 한글이 출력됩니다.
                                            style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 14),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (RoleType? val) {
                                        setState(() {
                                          _selectedManagerYn = val;
                                          // 한글 문자열 상태 변수도 함께 동기화 처리
                                          _selectedRole =
                                              (val == RoleType.admin)
                                                  ? '관리자'
                                                  : '멤버';
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(),
                                      ),
                                    )
                                  : TextFormField(
                                      // 일반 관리자 계정이거나 읽기 모드일 때는 안전하게 기존 방식 텍스트필드로 철저히 방어합니다.
                                      initialValue:
                                          widget.employee.role == 'ADMIN'
                                              ? '관리자'
                                              : '멤버',
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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

                            // 10. 상태
                            _buildRow(
                              '상태',
                              // Wrap으로 감싸서 부모 크기만큼 늘어나는 것을 방지합니다.
                              Wrap(
                                children: [
                                  RegisteStatusBadge(
                                    status: widget.employee.isRegisted == true
                                        ? '등록'
                                        : '미등록',
                                  ),
                                ],
                              ),
                            ),
                            // 11. 등록일 (항상 수정 불가능)
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
        _hireDateController.text = DateFormat('yyyy.MM.dd').format(picked);
      });
    }
  }

  // 공통 행 레이아웃 모듈 위젯
  Widget _buildRow(String label, Widget content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
