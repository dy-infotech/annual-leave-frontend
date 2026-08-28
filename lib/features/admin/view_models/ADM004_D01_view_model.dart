import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 사원 상세 화면(ADM004_D01)의 ViewModel.
class EmployeeDetailViewModel extends ChangeNotifier {
  EmployeeDetailViewModel({
    required this.employee,
    AdminEmployeeRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _repository = repository ?? AdminEmployeeRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository() {
    nameController = TextEditingController(text: employee.name);
    emailController = TextEditingController(text: employee.email ?? '');

    // 입사일 컨트롤러 초기화 및 0패딩 보장
    hireDateController = TextEditingController(
      text: employee.hireDate != null && employee.hireDate!.isNotEmpty
          ? DateFormat('yyyy.MM.dd').format(DateTime.parse(
              employee.hireDate!.contains('T')
                  ? employee.hireDate!.split('T')[0]
                  : employee.hireDate!))
          : '',
    );

    fireDateController = TextEditingController(
      text: employee.fireDate != null && employee.fireDate!.isNotEmpty
          ? DateFormat('yyyy.MM.dd').format(DateTime.parse(
              employee.fireDate!.contains('T')
                  ? employee.fireDate!.split('T')[0]
                  : employee.fireDate!))
          : '',
    );

    passwordController = TextEditingController();
    otherTeamController = TextEditingController();

    selectedDepartment = employee.department;
    selectedPosition = employee.position;
    selectedTeam = employee.team;

    // 기존 입사일 파싱 양식 유지
    if (employee.hireDate != null) {
      try {
        String rawHire = employee.hireDate!.trim();
        String cleanHire =
            rawHire.contains('T') ? rawHire.split('T')[0] : rawHire;
        if (cleanHire.length == 4) cleanHire = '$cleanHire-01-01';

        selectedHireDate = DateTime.parse(cleanHire);
      } catch (_) {}
    }

    // 퇴사일도 대칭되는 형태로 파싱
    if (employee.fireDate != null) {
      try {
        String rawFire = employee.fireDate!.trim();
        String cleanFire =
            rawFire.contains('T') ? rawFire.split('T')[0] : rawFire;
        if (cleanFire.length == 4) cleanFire = '$cleanFire-01-01';

        selectedFireDate = DateTime.parse(cleanFire);
      } catch (_) {}
    }
  }

  final Employee employee;
  final AdminEmployeeRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  bool _isEditing = false; // 현재 수정 모드 여부
  bool _isSaving = false; // 저장 API 호출 중 로딩 상태
  bool _isLoadingCommon = true; // 기초 데이터 로딩 상태

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController hireDateController;
  late final TextEditingController fireDateController;
  late final TextEditingController passwordController;
  late final TextEditingController otherTeamController; // 기타 팀 선택 시 입력

  final List<String> departmentList = [];
  final List<String> teamList = [];
  final List<String> positionList = [];

  String? selectedDepartment;
  String? selectedTeam;
  String? selectedPosition;

  DateTime? selectedHireDate; // 입사일 전용
  DateTime? selectedFireDate; // 퇴사일 전용

  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isLoadingCommon => _isLoadingCommon;

  void setEditing(bool editing) {
    _isEditing = editing;
    notifyListeners();
  }

  void selectDepartment(String? value) {
    selectedDepartment = value;
    notifyListeners();
  }

  void selectTeam(String? value) {
    selectedTeam = value;
    notifyListeners();
  }

  void selectPosition(String? value) {
    selectedPosition = value;
    notifyListeners();
  }

  Future<void> fetchCommonData() async {
    _isLoadingCommon = true;
    notifyListeners();
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();

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

      departmentList.clear();
      teamList.clear();
      positionList.clear();

      departmentList.addAll(fetchedDepartments);
      teamList.addAll(fetchedTeams);
      positionList.addAll(fetchedPositions);

      // 덮어쓰기 버그 예방: 이미 선택된 팀이 존재할 경우 리셋 연산 방어
      if (selectedTeam == null || !teamList.contains(selectedTeam)) {
        String? originalTeam = employee.team;
        if (originalTeam.isNotEmpty) {
          if (teamList.contains(originalTeam)) {
            selectedTeam = originalTeam;
          } else {
            teamList.add(originalTeam);
            selectedTeam = originalTeam;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 DB 공통 코드 로딩 중 에러 발생: $e');
    } finally {
      _isLoadingCommon = false;
      notifyListeners();
    }
  }

  /// 서버 저장 처리. 성공 시 잠금 모드로 되돌리고 true를 돌려준다.
  Future<bool> saveChanges() async {
    _isSaving = true;
    notifyListeners();
    try {
      String finalTeam = selectedTeam ?? '';

      String formattedHireDate =
          hireDateController.text.trim().replaceAll('.', '-');
      String formattedFireDate =
          fireDateController.text.trim().replaceAll('.', '-');

      print(
          '🚀 [API 전송 시작] hireDate: "$formattedHireDate", fireDate: "$formattedFireDate"');

      final statusCode = await _repository.updateEmployee(
        employee.employeeNumber,
        {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text.trim().isEmpty
              ? null
              : passwordController.text.trim(),
          'department': selectedDepartment,
          'team': finalTeam,
          'position': selectedPosition,

          'hireDate':
              formattedHireDate.isNotEmpty && formattedHireDate.length == 10
                  ? formattedHireDate
                  : null,

          'fireDate':
              formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                  ? formattedFireDate
                  : null,
          'firedDate':
              formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                  ? formattedFireDate
                  : null,

          'currTotalLeaveDays': employee.currTotalLeaveDays,
          // 관리자 역할 지정은 관리자별 관리팀 설정 화면(ADM001_M01)에서만 한다.
          // 이 화면에는 역할을 바꾸는 입력이 없으므로 역할 관련 값을 보내지 않는다.
        },
      );

      // 본문이 null 이어도 상태코드가 성공이면 화면 락 갱신 보장
      if (statusCode == 200 || statusCode == 204) {
        _isEditing = false; // 읽기 전용 폼 잠금 활성화
        passwordController.clear();

        // 저장 완료 후 컨트롤러 데이터를 유지시켜 즉시 조회 보장
        nameController.text = nameController.text.trim();
        emailController.text = emailController.text.trim();
        hireDateController.text = hireDateController.text.trim();
        fireDateController.text = fireDateController.text.trim();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ [API 호출 에러]: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    hireDateController.dispose();
    fireDateController.dispose();
    passwordController.dispose();
    otherTeamController.dispose();
    super.dispose();
  }
}
