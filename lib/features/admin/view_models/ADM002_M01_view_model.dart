import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/signup_manage_repository.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/models/enums/RoleType.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 사용자 등록 관리 화면(ADM002_M01)의 ViewModel.
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

  DateTime? selectedDate; // 선택된 날짜
  bool _isLoading = false;
  String? _errorMessage; //공통에러
  String? _employeeNumberError; //사번에러
  String? _employeeNameError; //사용자명에러
  String? _departmentError; //부서에러
  String? _teamError; //팀에러
  String? _positionError; //직급에러
  String? _emailError; //이메일에러
  String? _hireDateError; //입사일에러

  final List<String> teamList = []; //팀
  final List<String> departmentList = []; //부서
  final List<String> positionList = []; //직급
  String? selectedTeam; //선택된 팀
  String? selectedDepartment; //선택된 부서
  String? selectedPosition; //선택된 직급
  RoleType? selectedManagerYn = RoleType.employee; //선택된 관리자여부
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

  /// 관리자 역할 부여 가능 여부. 사장이면서 관리자인 접속자만 부여할 수 있다.
  static bool canAssignAdminRole({
    required String currentUserPosition,
    required String currentUserRole,
  }) {
    return currentUserPosition == "사장" && currentUserRole == "ADMIN";
  }

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();

      if (data.length >= 3) {
        DateTime today = DateTime.now();
        selectedDate = selectedDate ?? today;

        // 초기 로딩 시 서버 전송용 날짜 변수(formatDate) 세팅
        formatDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

        hireDateController.text =
            '${selectedDate!.year}년 ${selectedDate!.month}월 ${selectedDate!.day}일';

        departmentList.clear();
        teamList.clear();
        positionList.clear();

        departmentList.addAll(List<String>.from(data['department']));
        teamList.addAll(List<String>.from(data['accessibleTeam']));
        positionList.addAll(List<String>.from(data['position']));
      } else {
        // 데이터가 이상할 때 대비한 예외처리
        _errorMessage = '기초데이터 조회에 실패했습니다.';
      }
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 입력 검증. 기존 화면과 동일하게 첫 오류에서 중단한다.
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
    if (emailController.text.isEmpty) {
      _emailError = '이메일 정보를 입력해 주세요.';
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

  /// 사용자 등록. 성공 여부를 돌려준다.
  Future<bool> register() async {
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
      notifyListeners();
    }
  }

  void setHireDate(DateTime picked) {
    selectedDate = picked;
    formatDate = DateFormat('yyyy-MM-dd').format(picked);
    hireDateController.text = '${picked.year}년 ${picked.month}월 ${picked.day}일';
    _errorMessage = null; // 날짜 선택 시 오류 초기화
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
    selectedTeam = null; // 부서 변경 시 하위 팀 선택 값 강제 리셋
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
    employeeNumberController.dispose();
    employeeNameController.dispose();
    emailController.dispose();
    hireDateController.dispose();
    super.dispose();
  }
}
