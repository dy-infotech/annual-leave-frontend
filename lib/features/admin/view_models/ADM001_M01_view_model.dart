import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:flutter/material.dart';

/// 관리자별 관리팀 설정 화면(ADM001_M01)의 ViewModel.
class AdminSettingsViewModel extends ChangeNotifier {
  AdminSettingsViewModel({
    AdminEmployeeRepository? repository,
    CommonCodeRepository? commonCodeRepository,
  })  : _repository = repository ?? AdminEmployeeRepository(),
        _commonCodeRepository = commonCodeRepository ?? CommonCodeRepository();

  final AdminEmployeeRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  List<Employee> _employees = [];
  Employee? _selectedEmployee;

  List<String> _generalTeams = []; // 중앙: 일반 팀 목록
  List<String> _managedTeams = []; // 우측: 관리자 팀 목록
  Set<String> _changedTeams = {}; // 변경된 팀 목록 추적

  String? _selectedGeneralTeam; // 선택된 일반 팀
  String? _selectedManagedTeam; // 선택된 관리자 팀
  bool _isLoading = false;

  /// 사용자 이름 검색 입력. 조회 시점의 값을 그대로 쓰기 위해 VM이 소유한다.
  final TextEditingController employeeInfoController = TextEditingController();

  List<Employee> get employees => _employees;
  Employee? get selectedEmployee => _selectedEmployee;
  List<String> get generalTeams => _generalTeams;
  List<String> get managedTeams => _managedTeams;
  String? get selectedGeneralTeam => _selectedGeneralTeam;
  String? get selectedManagedTeam => _selectedManagedTeam;
  bool get isLoading => _isLoading;

  // 1. 사원 전체 목록 로드 (왼쪽 컬럼용)
  Future<void> fetchEmployees() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<Employee> fetched = await _repository.fetchEmployees();
      _employees = fetched;
      if (_employees.isNotEmpty) {
        _selectedEmployee = _employees.first; // 기본 첫 사원 자동 선택
        fetchEmployeeTeams();
      }
      notifyListeners();
    } catch (e) {
      print('사원 로드 실패: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. 선택된 사원의 '일반 팀' 및 '관리자 팀' 분리 로드
  Future<void> fetchEmployeeTeams() async {
    if (_selectedEmployee == null) return;
    try {
      // 공통 기초 데이터에서 시스템 전체의 모든 팀 목록 확보
      final commonData = await _commonCodeRepository.fetchCommonCodes();

      List<String> rawAllTeams = [];
      final rawTeams = commonData['accessibleTeam'] ?? commonData['team'] ?? [];
      if (rawTeams is List) {
        rawAllTeams = rawTeams.map((e) => e.toString()).toList();
      }

      // DB 중복 이름 방어: 동일한 이름이 있으면 "이름 (2)" 형태로 유니크하게 변환
      final List<String> uniqueAllTeams = [];
      final Map<String, int> nameCounter = {};

      for (var originalName in rawAllTeams) {
        if (nameCounter.containsKey(originalName)) {
          nameCounter[originalName] = nameCounter[originalName]! + 1;
          uniqueAllTeams.add('$originalName (${nameCounter[originalName]})');
        } else {
          nameCounter[originalName] = 1;
          uniqueAllTeams.add(originalName);
        }
      }

      // 1. 사용자의 권한 역할(Role) 파싱
      final String currentRole = (_selectedEmployee!.role ?? '').toUpperCase();
      final bool isAdmin = currentRole == 'ADMIN' || currentRole == 'MANAGER';

      final List<String> currentManaged = [];

      // 2. 관리자('ADMIN')인 경우 사원의 teamList 매핑 구성
      if (isAdmin) {
        final List<String> empTeams = [];
        if (_selectedEmployee!.teamList != null) {
          empTeams.addAll(_selectedEmployee!.teamList!);
        }

        // 사원이 가진 원본 이름을 고유 변환 이름 목록과 매핑하여 순서대로 할당
        for (var empTeamName in empTeams) {
          final matchedUniqueTeams = uniqueAllTeams
              .where((uTeam) =>
                  uTeam == empTeamName || uTeam.startsWith('$empTeamName ('))
              .toList();

          for (var matched in matchedUniqueTeams) {
            if (!currentManaged.contains(matched)) {
              currentManaged.add(matched);
            }
          }
        }
      }

      // 3. 최종 할당 및 중복 없는 필터링
      _managedTeams = isAdmin ? List<String>.from(currentManaged) : [];
      _generalTeams =
          uniqueAllTeams.where((t) => !_managedTeams.contains(t)).toList();

      // 선택 상태 초기화
      _selectedGeneralTeam = null;
      _selectedManagedTeam = null;
      notifyListeners();

      print('--- [DB 중복 방어 분리 완료] ---');
      print('전체 고유 팀 목록: $uniqueAllTeams');
      print('일반 팀 목록: $_generalTeams');
      print('관리 팀 목록: $_managedTeams');
    } catch (e) {
      print('팀 분리 매핑 로드 실패: $e');
    }
  }

  void selectEmployee(Employee emp) {
    _selectedEmployee = emp;
    employeeInfoController.text =
        '${emp.name} ${emp.position} ${emp.employeeNumber}';
    notifyListeners();
    fetchEmployeeTeams();
  }

  /// 이름과 일치하는 사원을 선택하고 목록 내 인덱스를 돌려준다. 없으면 -1.
  int selectEmployeeByName(String value) {
    final keyword = value.trim();

    final index = _employees.indexWhere(
      (e) => e.name == keyword,
    );

    if (index == -1) return -1;

    _selectedEmployee = _employees[index];
    notifyListeners();

    fetchEmployeeTeams();
    return index;
  }

  void selectGeneralTeam(String team) {
    _selectedGeneralTeam = team;
    _selectedManagedTeam = null;
    notifyListeners();
  }

  void selectManagedTeam(String team) {
    _selectedManagedTeam = team;
    _selectedGeneralTeam = null;
    notifyListeners();
  }

  void toggleChangedTeam(String team) {
    if (!_changedTeams.remove(team)) {
      _changedTeams.add(team);
    }
    notifyListeners();
  }

  // 3. [로컬 상태 변경] 일반 -> 관리자로 이동 ( > 버튼 )
  void moveToAdmin() {
    if (_selectedGeneralTeam == null) return;
    final team = _selectedGeneralTeam!;
    _generalTeams.remove(team);

    // 중복 방지를 위해 확인 후 추가
    if (!_managedTeams.contains(team)) {
      _managedTeams.add(team);
    }
    _selectedGeneralTeam = null;
    toggleChangedTeam(team);
  }

  // 4. [로컬 상태 변경] 관리자 -> 일반으로 이동 ( < 버튼 )
  void moveToGeneral() {
    if (_selectedManagedTeam == null) return;
    final team = _selectedManagedTeam!;
    _managedTeams.remove(team);

    // 중복 방지를 위해 확인 후 추가
    if (!_generalTeams.contains(team)) {
      _generalTeams.add(team);
    }
    _selectedManagedTeam = null;
    toggleChangedTeam(team);
  }

  // 5. [서버 전송] 저장. 실패 시 보여줄 메시지를 돌려준다. (성공/무응답 시 null)
  Future<String?> saveChanges() async {
    if (_selectedEmployee == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final statusCode = await _repository.updateEmployee(
        _selectedEmployee!.employeeNumber,
        {
          'name': _selectedEmployee!.name,
          'email': _selectedEmployee!.email ?? '',
          'department': _selectedEmployee!.department,
          'team': _selectedEmployee!.team,
          'position': _selectedEmployee!.position,
          'hireDate': _selectedEmployee!.hireDate,
          'targetTeamsForRoleSwap': _changedTeams.toList(),
        },
      );

      if (statusCode == 200 || statusCode == 204) {
        fetchEmployees(); // 완료 후 리스트 리프레시
      }
      return null;
    } catch (e) {
      print('권한 설정 저장 실패: $e');
      return '저장 중 오류가 발생했습니다.';
    } finally {
      _changedTeams = {};
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    employeeInfoController.dispose();
    super.dispose();
  }
}
