import 'package:flutter/foundation.dart';
import '../model/dto/admin_registration_dto.dart';
import '../model/api_client/admin_registration_api_client.dart';
import '../model/enum/role_type.dart';

class AdminRegistrationViewModel extends ChangeNotifier {
  final AdminRegistrationApiClient _apiClient;
  AdminRegistrationViewModel(this._apiClient);

  bool _isLoadingOptions = false;
  bool _isSubmitting = false;
  String? _loadError;

  List<String> _departments = [];
  List<String> _teams = [];
  List<String> _positions = [];

  // 필드별 인라인 에러 (기존 화면의 TextField errorText와 1:1 대응)
  String? nameError;
  String? departmentError;
  String? teamError;
  String? positionError;
  String? roleError;
  String? emailError;
  String? hireDateError;

  bool get isLoadingOptions => _isLoadingOptions;
  bool get isSubmitting => _isSubmitting;
  String? get loadError => _loadError;
  List<String> get departments => _departments;
  List<String> get positions => _positions;

  // "대표이사"인 관리자가 신규 팀을 만들 때만 '기타' 옵션을 보여줄지는
  // 이 화면을 보고 있는 사용자(Profile)에 대한 정책이라, View가 조건을
  // 판단해서 넘겨준다. ViewModel은 자기 목록만 순수하게 관리한다.
  List<String> teamOptions({required bool includeOtherOption}) {
    if (includeOtherOption && !_teams.contains('기타')) {
      return [..._teams, '기타'];
    }
    return _teams;
  }

  void clearFieldError(String field) {
    switch (field) {
      case 'name': nameError = null; break;
      case 'department': departmentError = null; break;
      case 'team': teamError = null; break;
      case 'position': positionError = null; break;
      case 'role': roleError = null; break;
      case 'email': emailError = null; break;
      case 'hireDate': hireDateError = null; break;
    }
    notifyListeners();
  }

  Future<void> loadOptions() async {
    _isLoadingOptions = true;
    _loadError = null;
    notifyListeners();

    try {
      final options = await _apiClient.fetchCommonOptions();
      _departments = options.departments;
      _teams = options.teams;
      _positions = options.positions;
    } catch (e) {
      _loadError = '기초데이터 조회에 실패했습니다.';
    } finally {
      _isLoadingOptions = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String department,
    required String team,
    required String position,
    required RoleType? role,
    required String email,
    required DateTime? hireDate,
  }) async {
    nameError = name.isEmpty ? '사용자명을 입력해 주세요.' : null;
    departmentError = department.isEmpty ? '부서를 입력해 주세요.' : null;
    teamError = team.isEmpty ? '팀을 선택해 주세요.' : null;
    positionError = position.isEmpty ? '직급을 입력해 주세요.' : null;
    roleError = role == null ? '관리자여부를 선택해 주세요.' : null;
    emailError = email.isEmpty ? '이메일 정보를 입력해 주세요.' : null;
    hireDateError = hireDate == null ? '입사일 정보를 입력해 주세요.' : null;

    final hasError = [nameError, departmentError, teamError, positionError, roleError, emailError, hireDateError]
        .any((e) => e != null);
    if (hasError) {
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    try {
      await _apiClient.register(AdminAuthRegisterRequestDto(
        name: name,
        department: department,
        team: team,
        position: position,
        role: role!.code,
        email: email,
        hireDate: _formatDate(hireDate!),
      ));
      return true;
    } catch (e) {
      _loadError = '사용자 등록에 실패했습니다.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
