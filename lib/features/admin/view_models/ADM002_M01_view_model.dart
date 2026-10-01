import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/signup_manage_repository.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/models/enums/RoleType.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 사용자 등록 입력과 기초 코드 상태를 관리한다
class SignupManageViewModel extends ChangeNotifier {
  SignupManageViewModel({
    SignupManageRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _signupRepository = repository ?? SignupManageRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository();

  final SignupManageRepository _signupRepository;
  final CommonCodeRepository _commonCodeRepository;

  final employeeNumberController = TextEditingController();
  final employeeNameController = TextEditingController();
  final emailController = TextEditingController();
  final hireDateController = TextEditingController();

  DateTime? selectedDate; // 선택한 입사일을 보관한다
  bool _isLoading = false;
  bool _disposed = false;
  int _requestSeq = 0;
  String? _errorMessage; // 공통 오류를 보관한다
  String? _employeeNumberError; // 사번 오류를 보관한다
  String? _employeeNameError; // 사용자명 오류를 보관한다
  String? _departmentError; // 부서 오류를 보관한다
  String? _teamError; // 팀 오류를 보관한다
  String? _positionError; // 직급 오류를 보관한다
  String? _emailError; // 이메일 오류를 보관한다
  String? _hireDateError; // 입사일 오류를 보관한다

  final List<String> teamList = []; // 기존 화면용 팀명 목록을 유지한다
  final List<AccessibleTeamOption> teamOptions = []; // 부서 관계를 포함한 팀 목록이다
  final List<String> departmentList = []; // 부서 목록을 보관한다
  final List<String> positionList = []; // 직급 목록을 보관한다
  String? selectedTeam; // 선택한 팀을 보관한다
  String? selectedDepartment; // 선택한 부서를 보관한다
  String? selectedPosition; // 선택한 직급을 보관한다
  RoleType? selectedManagerYn = RoleType.employee; // 선택한 역할을 보관한다
  String? formatDate;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get employeeNumberError => _employeeNumberError;
  String? get employeeNameError => _employeeNameError;
  String? get departmentError => _departmentError;
  String? get teamError => _teamError;
  String? get positionError => _positionError;
  String? get emailError => _emailError;
  String? get hireDateError => _hireDateError;

  List<String> get availableTeams {
    final department = selectedDepartment;
    if (department == null) return const [];

    if (teamOptions.isNotEmpty) {
      return teamOptions
          .where((team) => team.departmentName == department)
          .map((team) => team.teamName)
          .toList();
    }

    // 현재 팀 정보가 없을 때 기존 팀 목록을 보조로 사용한다
    return List<String>.unmodifiable(teamList);
  }

  // 현재 인사권 기준으로 관리자 역할 부여 가능 여부를 확인한다
  static bool canAssignAdminRole({Employee? currentUser}) {
    return currentUser?.isCeo ?? false;
  }

  Future<void> fetch() async {
    if (_disposed) return;
    final seq = ++_requestSeq;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
      if (_disposed || seq != _requestSeq) return;

      if (data.length >= 3) {
        DateTime today = DateTime.now();
        selectedDate = selectedDate ?? today;

        // 초기 입사일을 서버 전송 형식으로 맞춘다
        formatDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

        hireDateController.text =
            '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일';

        departmentList.clear();
        teamList.clear();
        teamOptions.clear();
        positionList.clear();

        departmentList.addAll(List<String>.from(data['department']));
        teamList.addAll(List<String>.from(data['accessibleTeam']));

        final rawTeamInfo = data['accessibleTeamInfo'];
        if (rawTeamInfo is List) {
          for (final item in rawTeamInfo) {
            if (item is Map) {
              teamOptions.add(
                AccessibleTeamOption.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            }
          }
        }

        positionList.addAll(List<String>.from(data['position']));
      } else {
        // 기초 코드 형식이 다르면 빈 목록을 유지한다
        _errorMessage = '기초데이터 조회에 실패했습니다.';
      }
      notifyListeners();
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // 입력값을 순서대로 확인하고 첫 오류에서 중단한다
  bool validateInputs() {
    if (employeeNumberController.text.isEmpty) {
      _employeeNumberError = '사번을 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (employeeNameController.text.isEmpty) {
      _employeeNameError = '사용자명을 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (selectedDepartment == null) {
      _departmentError = '부서를 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (selectedTeam == null) {
      _teamError = '팀을 선택해 주세요.';
      notifyListeners();
      return false;
    }
    if (selectedPosition == null) {
      _positionError = '직급을 입력해 주세요.';
      notifyListeners();
      return false;
    }
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _emailError = '이메일 정보를 입력해 주세요.';
      notifyListeners();
      return false;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+');
    if (emailRegex.stringMatch(email) != email) {
      _emailError = '올바른 이메일 형식이 아닙니다.';
      notifyListeners();
      return false;
    }
    if (hireDateController.text.isEmpty) {
      _hireDateError = '입사일 정보를 입력해 주세요.';
      notifyListeners();
      return false;
    }
    return true;
  }

  // 검증된 입력값으로 사용자 등록을 요청한다
  Future<bool> register() async {
    if (_disposed || _isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signupRepository.registerUser(AdminAuthRegisterRequest(
        employeeNumber: employeeNumberController.text.trim(),
        name: employeeNameController.text.trim(),
        department: selectedDepartment ?? '',
        team: selectedTeam ?? '',
        position: selectedPosition ?? '',
        role: selectedManagerYn?.code ?? '',
        email: emailController.text.trim(),
        hireDate: formatDate.toString(),
      ));
      return true;
    } catch (e) {
      _errorMessage = e.toString().contains('Exception')
          ? '사용자 등록에 실패했습니다.' + e.toString()
          : '';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setHireDate(DateTime picked) {
    selectedDate = picked;
    formatDate = DateFormat('yyyy-MM-dd').format(picked);
    hireDateController.text = '${picked.year}년 ${picked.month}월 ${picked.day}일';
    _errorMessage = null; // 날짜 변경 시 이전 오류를 지운다
    notifyListeners();
  }

  void clearEmployeeNumberError() {
    _employeeNumberError = null;
    notifyListeners();
  }

  void clearEmployeeNameError() {
    _employeeNameError = null;
    notifyListeners();
  }

  void clearEmailError() {
    _emailError = null;
    notifyListeners();
  }

  void clearHireDateError() {
    _hireDateError = null;
    notifyListeners();
  }

  void selectDepartment(String? value) {
    selectedDepartment = value;
    _departmentError = null;
    selectedTeam = null; // 부서 변경 시 기존 팀 선택을 지운다
    notifyListeners();
  }

  void selectTeam(String? value) {
    selectedTeam = value;
    _teamError = null;
    notifyListeners();
  }

  void selectPosition(String? value) {
    selectedPosition = value;
    _positionError = null;
    notifyListeners();
  }

  void selectManagerYn(RoleType? value) {
    selectedManagerYn = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    employeeNumberController.dispose();
    employeeNameController.dispose();
    emailController.dispose();
    hireDateController.dispose();
    super.dispose();
  }
}
