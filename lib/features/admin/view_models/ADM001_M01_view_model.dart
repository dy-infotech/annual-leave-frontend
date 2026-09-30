import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:dio/dio.dart';
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

  List<String> _generalTeams = [];
  List<String> _managedTeams = [];
  Set<String> _expectedManagedTeams = {};
  Set<String> _changedTeams = {};

  String? _selectedGeneralTeam;
  String? _selectedManagedTeam;
  bool _isLoading = false;
  bool _needsReconcile = false;
  int _teamLoadSeq = 0;
  bool _disposed = false;

  /// 사용자 이름 검색 입력. 조회 시점의 값을 그대로 쓰기 위해 VM이 소유한다.
  final TextEditingController employeeInfoController = TextEditingController();

  List<Employee> get employees => _employees;
  Employee? get selectedEmployee => _selectedEmployee;
  List<String> get generalTeams => _generalTeams;
  List<String> get managedTeams => _managedTeams;
  String? get selectedGeneralTeam => _selectedGeneralTeam;
  String? get selectedManagedTeam => _selectedManagedTeam;
  bool get isLoading => _isLoading;
  bool get needsReconcile => _needsReconcile;
  bool get hasChanges => _changedTeams.isNotEmpty;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> fetchEmployees() async {
    _isLoading = true;
    _notify();

    try {
      final fetched = await _repository.fetchEmployees();
      if (_disposed) return;

      final previousNumber = _selectedEmployee?.employeeNumber;
      Employee? selected;
      if (fetched.isNotEmpty) {
        selected = previousNumber == null
            ? fetched.first
            : fetched.firstWhere(
                (employee) => employee.employeeNumber == previousNumber,
                orElse: () => fetched.first,
              );
      }

      _employees = fetched;
      _selectedEmployee = selected;
      if (selected == null) {
        _generalTeams = [];
        _managedTeams = [];
        _expectedManagedTeams = {};
        _changedTeams = {};
        _selectedGeneralTeam = null;
        _selectedManagedTeam = null;
        employeeInfoController.clear();
      } else {
        employeeInfoController.text =
            '${selected.name} ${selected.position} ${selected.employeeNumber}';
      }
      _notify();

      if (selected != null) {
        await fetchEmployeeTeams();
      }
    } catch (e) {
      debugPrint('사원 로드 실패: $e');
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// 선택된 사원의 일반 팀/관리 팀을 마지막 서버 상태 기준으로 다시 구성한다.
  Future<bool> fetchEmployeeTeams() async {
    final selected = _selectedEmployee;
    if (selected == null) return false;

    final seq = ++_teamLoadSeq;
    try {
      final commonData = await _commonCodeRepository.fetchCommonCodes();

      final rawTeams = commonData['accessibleTeam'] ?? commonData['team'] ?? [];
      final allTeams = <String>[];
      if (rawTeams is List) {
        for (final item in rawTeams) {
          final name = item is Map
              ? (item['teamName']?.toString() ?? item['name']?.toString())
              : item.toString();
          if (name != null && name.isNotEmpty && !allTeams.contains(name)) {
            allTeams.add(name);
          }
        }
      }

      final role = (selected.role ?? '').toUpperCase();
      final isAdmin = role == 'ADMIN' || role == 'MANAGER';
      final managedNames =
          isAdmin ? (selected.teamList ?? const <String>[]).toSet() : <String>{};

      if (_disposed ||
          seq != _teamLoadSeq ||
          _selectedEmployee?.employeeNumber != selected.employeeNumber) {
        return false;
      }

      _managedTeams =
          allTeams.where((team) => managedNames.contains(team)).toList();
      _generalTeams =
          allTeams.where((team) => !managedNames.contains(team)).toList();
      _expectedManagedTeams = Set<String>.from(_managedTeams);
      _changedTeams = {};
      _needsReconcile = false;
      _selectedGeneralTeam = null;
      _selectedManagedTeam = null;
      _notify();
      return true;
    } catch (e) {
      debugPrint('팀 분리 매핑 로드 실패: $e');
      return false;
    }
  }

  /// 미저장 변경이 있으면 다른 직원을 선택하지 않는다.
  bool selectEmployee(Employee emp) {
    if (_isLoading || _needsReconcile || hasChanges) return false;
    if (_selectedEmployee?.employeeNumber == emp.employeeNumber) return true;

    _selectedEmployee = emp;
    employeeInfoController.text =
        '${emp.name} ${emp.position} ${emp.employeeNumber}';
    _generalTeams = [];
    _managedTeams = [];
    _expectedManagedTeams = {};
    _changedTeams = {};
    _selectedGeneralTeam = null;
    _selectedManagedTeam = null;
    _notify();
    fetchEmployeeTeams();
    return true;
  }

  /// 이름과 일치하는 사원을 선택하고 목록 내 인덱스를 돌려준다. 없거나 전환 불가면 -1.
  int selectEmployeeByName(String value) {
    final keyword = value.trim();
    final index = _employees.indexWhere((e) => e.name == keyword);
    if (index == -1) return -1;
    return selectEmployee(_employees[index]) ? index : -1;
  }

  void selectGeneralTeam(String team) {
    if (_needsReconcile || _isLoading) return;
    _selectedGeneralTeam = team;
    _selectedManagedTeam = null;
    _notify();
  }

  void selectManagedTeam(String team) {
    if (_needsReconcile || _isLoading) return;
    _selectedManagedTeam = team;
    _selectedGeneralTeam = null;
    _notify();
  }

  void toggleChangedTeam(String team) {
    if (!_changedTeams.remove(team)) {
      _changedTeams.add(team);
    }
    _notify();
  }

  void moveToAdmin() {
    if (_needsReconcile || _isLoading || _selectedGeneralTeam == null) return;
    final team = _selectedGeneralTeam!;
    _generalTeams.remove(team);
    if (!_managedTeams.contains(team)) {
      _managedTeams.add(team);
    }
    _selectedGeneralTeam = null;
    toggleChangedTeam(team);
  }

  void moveToGeneral() {
    if (_needsReconcile || _isLoading || _selectedManagedTeam == null) return;
    final team = _selectedManagedTeam!;
    _managedTeams.remove(team);
    if (!_generalTeams.contains(team)) {
      _generalTeams.add(team);
    }
    _selectedManagedTeam = null;
    toggleChangedTeam(team);
  }

  bool _isAmbiguousWriteFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    return error.response == null ||
        statusCode == 408 ||
        (statusCode != null && statusCode >= 500);
  }

  Future<bool> _reloadSelectedFromServer(String employeeNumber) async {
    try {
      final fetched =
          await _repository.fetchEmployees(searchParam: employeeNumber);
      if (_disposed) return false;

      final matches = fetched
          .where((employee) => employee.employeeNumber == employeeNumber)
          .toList();
      if (matches.isEmpty) return false;

      final current = matches.first;
      final index = _employees
          .indexWhere((employee) => employee.employeeNumber == employeeNumber);
      if (index >= 0) {
        _employees[index] = current;
      } else {
        _employees.add(current);
      }
      _selectedEmployee = current;
      employeeInfoController.text =
          '${current.name} ${current.position} ${current.employeeNumber}';
      _notify();

      return fetchEmployeeTeams();
    } catch (e) {
      debugPrint('선택 직원 서버 상태 재조회 실패: $e');
      return false;
    }
  }

  /// 충돌/결과 불명확 상태에서 서버의 현재 값을 다시 읽는다.
  Future<String?> reconcileSelected() async {
    final employee = _selectedEmployee;
    if (_isLoading || employee == null) return null;

    _isLoading = true;
    _notify();
    try {
      final reloaded =
          await _reloadSelectedFromServer(employee.employeeNumber);
      if (!reloaded) {
        _needsReconcile = true;
        return '서버 상태를 불러오지 못했습니다. 다시 시도해 주세요.';
      }
      _needsReconcile = false;
      return null;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// 마지막 조회 상태(expected)와 화면의 최종 상태(desired)를 함께 보내 CAS로 저장한다.
  Future<String?> saveChanges() async {
    final employee = _selectedEmployee;
    if (_isLoading ||
        _needsReconcile ||
        employee == null ||
        _changedTeams.isEmpty) {
      return null;
    }

    final desired = List<String>.from(_managedTeams);
    final expected = _expectedManagedTeams.toList();
    _isLoading = true;
    _notify();

    try {
      final statusCode = await _repository.updateManagedTeams(
        employee.employeeNumber,
        expectedManagedTeams: expected,
        managedTeams: desired,
      );

      if (statusCode == 200 || statusCode == 204) {
        final reloaded =
            await _reloadSelectedFromServer(employee.employeeNumber);
        if (!reloaded) {
          _needsReconcile = true;
          return '저장은 완료됐지만 최신 상태를 다시 불러오지 못했습니다. 서버 상태를 재조회해 주세요.';
        }
      }
      return null;
    } on DioException catch (e) {
      if (_disposed) return null;

      final staleConflict = e.response?.statusCode == 409;
      final ambiguous = _isAmbiguousWriteFailure(e);
      if (staleConflict || ambiguous) {
        _needsReconcile = true;
        final reloaded =
            await _reloadSelectedFromServer(employee.employeeNumber);
        if (reloaded) {
          return staleConflict
              ? '다른 변경이 먼저 반영되어 서버의 최신 관리팀 상태를 다시 불러왔습니다.'
              : '저장 결과가 불명확해 서버의 현재 관리팀 상태를 다시 불러왔습니다.';
        }
        return staleConflict
            ? '다른 변경이 먼저 반영되었습니다. 서버 상태를 다시 조회해 주세요.'
            : '저장 결과를 확인하지 못했습니다. 서버 상태를 다시 조회해 주세요.';
      }
      return e.message ?? '저장 중 오류가 발생했습니다.';
    } catch (e) {
      debugPrint('권한 설정 저장 실패: $e');
      _needsReconcile = true;
      return '저장 결과를 확인하지 못했습니다. 서버 상태를 다시 조회해 주세요.';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    employeeInfoController.dispose();
    super.dispose();
  }
}
