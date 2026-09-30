import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/admin_employee_repository.dart';
import 'package:annual_leave_frontend/features/admin/repositories/common_code_repository.dart';
import 'package:dio/dio.dart';
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

    final hireDate = _normalizeApiDate(employee.hireDate);
    final fireDate = _normalizeApiDate(employee.fireDate);
    hireDateController = TextEditingController(
      text: hireDate == null
          ? ''
          : DateFormat('yyyy.MM.dd').format(DateTime.parse(hireDate)),
    );
    fireDateController = TextEditingController(
      text: fireDate == null
          ? ''
          : DateFormat('yyyy.MM.dd').format(DateTime.parse(fireDate)),
    );

    selectedDepartment = employee.department;
    selectedPosition = employee.position;
    selectedTeam = employee.team;
    selectedHireDate = hireDate == null ? null : DateTime.tryParse(hireDate);
    selectedFireDate = fireDate == null ? null : DateTime.tryParse(fireDate);
    _expectedEmployeeState = _employeeStateFromModel(employee);
  }

  final Employee employee;
  final AdminEmployeeRepository _repository;
  final CommonCodeRepository _commonCodeRepository;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoadingCommon = true;
  bool _disposed = false;
  String? _lastSaveMessage;

  late Map<String, dynamic> _expectedEmployeeState;

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController hireDateController;
  late final TextEditingController fireDateController;

  final List<String> departmentList = [];
  final List<String> teamList = []; // 하위 호환용 팀명 목록
  final List<AccessibleTeamOption> teamOptions = [];
  final List<String> positionList = [];

  String? selectedDepartment;
  String? selectedTeam;
  String? selectedPosition;

  DateTime? selectedHireDate;
  DateTime? selectedFireDate;

  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isLoadingCommon => _isLoadingCommon;
  String? get lastSaveMessage => _lastSaveMessage;

  List<String> get availableTeams {
    final department = selectedDepartment;
    if (department == null) return const [];

    if (teamOptions.isNotEmpty) {
      final result = teamOptions
          .where((team) => team.departmentName == department)
          .map((team) => team.teamName)
          .toList();

      // 현재 배정값은 공통데이터 접근범위 밖이어도 조회/수정 화면에서 잃지 않는다.
      if (department == employee.department &&
          employee.team.isNotEmpty &&
          !result.contains(employee.team)) {
        result.add(employee.team);
      }
      return result;
    }

    return List<String>.unmodifiable(teamList);
  }

  static String? _normalizeApiDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = raw.trim();
    if (RegExp(r'^\d{4}

  static Map<String, dynamic> _employeeStateFromModel(Employee employee) {
    return {
      'name': employee.name,
      'email': employee.email,
      'department': employee.department,
      'team': employee.team,
      'position': employee.position,
      'hireDate': _normalizeApiDate(employee.hireDate),
      'fireDate': _normalizeApiDate(employee.fireDate),
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setEditing(bool editing) {
    _isEditing = editing;
    _notify();
  }

  void selectDepartment(String? value) {
    selectedDepartment = value;
    if (selectedTeam != null && !availableTeams.contains(selectedTeam)) {
      selectedTeam = null;
    }
    _notify();
  }

  void selectTeam(String? value) {
    selectedTeam = value;
    _notify();
  }

  void selectPosition(String? value) {
    selectedPosition = value;
    _notify();
  }

  void _applyServerEmployee(Employee current) {
    final hireDate = _normalizeApiDate(current.hireDate);
    final fireDate = _normalizeApiDate(current.fireDate);

    nameController.text = current.name;
    emailController.text = current.email ?? '';
    hireDateController.text = hireDate == null
        ? ''
        : DateFormat('yyyy.MM.dd').format(DateTime.parse(hireDate));
    fireDateController.text = fireDate == null
        ? ''
        : DateFormat('yyyy.MM.dd').format(DateTime.parse(fireDate));
    selectedDepartment = current.department;
    selectedTeam = current.team;
    selectedPosition = current.position;
    selectedHireDate = hireDate == null ? null : DateTime.tryParse(hireDate);
    selectedFireDate = fireDate == null ? null : DateTime.tryParse(fireDate);
    _expectedEmployeeState = _employeeStateFromModel(current);
    _isEditing = false;
  }

  Future<bool> _reloadEmployeeFromServer() async {
    try {
      final fetched =
          await _repository.fetchEmployees(searchParam: employee.employeeNumber);
      if (_disposed) return false;

      final matches = fetched
          .where((item) => item.employeeNumber == employee.employeeNumber)
          .toList();
      if (matches.isEmpty) return false;

      _applyServerEmployee(matches.first);
      _notify();
      return true;
    } catch (e) {
      debugPrint('사원 최신 상태 재조회 실패: $e');
      return false;
    }
  }

  Future<void> fetchCommonData() async {
    _isLoadingCommon = true;
    _notify();
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
      if (_disposed) return;

      final fetchedDepartments =
          List<String>.from(data['department'] ?? const []);
      final fetchedPositions =
          List<String>.from(data['position'] ?? const []);
      final rawTeamData = data['accessibleTeam'] ?? data['team'] ?? [];
      final fetchedTeams = <String>[];
      final fetchedTeamOptions = <AccessibleTeamOption>[];

      if (rawTeamData is List) {
        for (final item in rawTeamData) {
          if (item is String) {
            fetchedTeams.add(item);
          } else if (item is Map) {
            final name =
                item['teamName']?.toString() ?? item['name']?.toString();
            if (name != null) fetchedTeams.add(name);
          }
        }
      }

      final rawTeamInfo = data['accessibleTeamInfo'];
      if (rawTeamInfo is List) {
        for (final item in rawTeamInfo) {
          if (item is Map) {
            fetchedTeamOptions.add(
              AccessibleTeamOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      departmentList
        ..clear()
        ..addAll(fetchedDepartments);
      teamList
        ..clear()
        ..addAll(fetchedTeams);
      teamOptions
        ..clear()
        ..addAll(fetchedTeamOptions);
      positionList
        ..clear()
        ..addAll(fetchedPositions);

      if (selectedTeam != null &&
          selectedTeam!.isNotEmpty &&
          !teamList.contains(selectedTeam)) {
        teamList.add(selectedTeam!);
      }
      _notify();
    } catch (e) {
      debugPrint('DB 공통 코드 로딩 중 에러 발생: $e');
    } finally {
      if (!_disposed) {
        _isLoadingCommon = false;
        _notify();
      }
    }
  }

  bool _isAmbiguousWriteFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    return error.response == null ||
        statusCode == 408 ||
        (statusCode != null && statusCode >= 500);
  }

  /// 편집 가능한 현재 상태만 desired로 보내고, 마지막 조회 상태를 expected로 함께 전송한다.
  Future<bool> saveChanges() async {
    if (_isSaving) return false;

    _isSaving = true;
    _lastSaveMessage = null;
    _notify();

    try {
      final formattedHireDate =
          hireDateController.text.trim().replaceAll('.', '-');
      final formattedFireDate =
          fireDateController.text.trim().replaceAll('.', '-');

      final desiredState = <String, dynamic>{
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'department': selectedDepartment,
        'team': selectedTeam ?? '',
        'position': selectedPosition,
        'hireDate':
            formattedHireDate.isNotEmpty && formattedHireDate.length == 10
                ? formattedHireDate
                : null,
        'fireDate':
            formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                ? formattedFireDate
                : null,
      };

      final statusCode = await _repository.updateEmployee(
        employee.employeeNumber,
        {
          'expected': Map<String, dynamic>.from(_expectedEmployeeState),
          ...desiredState,
        },
      );

      if (statusCode == 200 || statusCode == 204) {
        _expectedEmployeeState = Map<String, dynamic>.from(desiredState);
        _isEditing = false;

        nameController.text = nameController.text.trim();
        emailController.text = emailController.text.trim();
        hireDateController.text = hireDateController.text.trim();
        fireDateController.text = fireDateController.text.trim();
        _notify();
        return true;
      }

      _lastSaveMessage = '사원 정보 저장에 실패했습니다.';
      return false;
    } on DioException catch (e) {
      if (_disposed) return false;

      final staleConflict = e.response?.statusCode == 409;
      final ambiguous = _isAmbiguousWriteFailure(e);
      if (staleConflict || ambiguous) {
        final reloaded = await _reloadEmployeeFromServer();
        if (reloaded) {
          _lastSaveMessage = staleConflict
              ? '다른 변경이 먼저 반영되어 최신 사원 정보를 다시 불러왔습니다.'
              : '저장 결과가 불명확해 서버의 현재 사원 정보를 다시 불러왔습니다.';
        } else {
          _lastSaveMessage =
              '최신 사원 정보를 다시 불러오지 못했습니다. 화면을 다시 열어 주세요.';
        }
      } else {
        _lastSaveMessage = e.message ?? '사원 정보 저장에 실패했습니다.';
      }
      return false;
    } catch (e) {
      debugPrint('사원 정보 저장 실패: $e');
      _lastSaveMessage = '사원 정보 저장에 실패했습니다.';
      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    emailController.dispose();
    hireDateController.dispose();
    fireDateController.dispose();
    super.dispose();
  }
}
).hasMatch(value)) {
      value = '$value-01-01';
    } else if (value.contains('T')) {
      value = value.split('T')[0];
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic> _employeeStateFromModel(Employee employee) {
    return {
      'name': employee.name,
      'email': employee.email,
      'department': employee.department,
      'team': employee.team,
      'position': employee.position,
      'hireDate': _normalizeApiDate(employee.hireDate),
      'fireDate': _normalizeApiDate(employee.fireDate),
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setEditing(bool editing) {
    _isEditing = editing;
    _notify();
  }

  void selectDepartment(String? value) {
    selectedDepartment = value;
    if (selectedTeam != null && !availableTeams.contains(selectedTeam)) {
      selectedTeam = null;
    }
    _notify();
  }

  void selectTeam(String? value) {
    selectedTeam = value;
    _notify();
  }

  void selectPosition(String? value) {
    selectedPosition = value;
    _notify();
  }

  void _applyServerEmployee(Employee current) {
    final hireDate = _normalizeApiDate(current.hireDate);
    final fireDate = _normalizeApiDate(current.fireDate);

    nameController.text = current.name;
    emailController.text = current.email ?? '';
    hireDateController.text = hireDate == null
        ? ''
        : DateFormat('yyyy.MM.dd').format(DateTime.parse(hireDate));
    fireDateController.text = fireDate == null
        ? ''
        : DateFormat('yyyy.MM.dd').format(DateTime.parse(fireDate));
    selectedDepartment = current.department;
    selectedTeam = current.team;
    selectedPosition = current.position;
    selectedHireDate = hireDate == null ? null : DateTime.tryParse(hireDate);
    selectedFireDate = fireDate == null ? null : DateTime.tryParse(fireDate);
    _expectedEmployeeState = _employeeStateFromModel(current);
    _isEditing = false;
  }

  Future<bool> _reloadEmployeeFromServer() async {
    try {
      final fetched =
          await _repository.fetchEmployees(searchParam: employee.employeeNumber);
      if (_disposed) return false;

      final matches = fetched
          .where((item) => item.employeeNumber == employee.employeeNumber)
          .toList();
      if (matches.isEmpty) return false;

      _applyServerEmployee(matches.first);
      _notify();
      return true;
    } catch (e) {
      debugPrint('사원 최신 상태 재조회 실패: $e');
      return false;
    }
  }

  Future<void> fetchCommonData() async {
    _isLoadingCommon = true;
    _notify();
    try {
      final data = await _commonCodeRepository.fetchCommonCodes();
      if (_disposed) return;

      final fetchedDepartments =
          List<String>.from(data['department'] ?? const []);
      final fetchedPositions =
          List<String>.from(data['position'] ?? const []);
      final rawTeamData = data['accessibleTeam'] ?? data['team'] ?? [];
      final fetchedTeams = <String>[];
      final fetchedTeamOptions = <AccessibleTeamOption>[];

      if (rawTeamData is List) {
        for (final item in rawTeamData) {
          if (item is String) {
            fetchedTeams.add(item);
          } else if (item is Map) {
            final name =
                item['teamName']?.toString() ?? item['name']?.toString();
            if (name != null) fetchedTeams.add(name);
          }
        }
      }

      final rawTeamInfo = data['accessibleTeamInfo'];
      if (rawTeamInfo is List) {
        for (final item in rawTeamInfo) {
          if (item is Map) {
            fetchedTeamOptions.add(
              AccessibleTeamOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          }
        }
      }

      departmentList
        ..clear()
        ..addAll(fetchedDepartments);
      teamList
        ..clear()
        ..addAll(fetchedTeams);
      teamOptions
        ..clear()
        ..addAll(fetchedTeamOptions);
      positionList
        ..clear()
        ..addAll(fetchedPositions);

      if (selectedTeam != null &&
          selectedTeam!.isNotEmpty &&
          !teamList.contains(selectedTeam)) {
        teamList.add(selectedTeam!);
      }
      _notify();
    } catch (e) {
      debugPrint('DB 공통 코드 로딩 중 에러 발생: $e');
    } finally {
      if (!_disposed) {
        _isLoadingCommon = false;
        _notify();
      }
    }
  }

  bool _isAmbiguousWriteFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    return error.response == null ||
        statusCode == 408 ||
        (statusCode != null && statusCode >= 500);
  }

  /// 편집 가능한 현재 상태만 desired로 보내고, 마지막 조회 상태를 expected로 함께 전송한다.
  Future<bool> saveChanges() async {
    if (_isSaving) return false;

    _isSaving = true;
    _lastSaveMessage = null;
    _notify();

    try {
      final formattedHireDate =
          hireDateController.text.trim().replaceAll('.', '-');
      final formattedFireDate =
          fireDateController.text.trim().replaceAll('.', '-');

      final desiredState = <String, dynamic>{
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'department': selectedDepartment,
        'team': selectedTeam ?? '',
        'position': selectedPosition,
        'hireDate':
            formattedHireDate.isNotEmpty && formattedHireDate.length == 10
                ? formattedHireDate
                : null,
        'fireDate':
            formattedFireDate.isNotEmpty && formattedFireDate.length == 10
                ? formattedFireDate
                : null,
      };

      final statusCode = await _repository.updateEmployee(
        employee.employeeNumber,
        {
          'expected': Map<String, dynamic>.from(_expectedEmployeeState),
          ...desiredState,
        },
      );

      if (statusCode == 200 || statusCode == 204) {
        _expectedEmployeeState = Map<String, dynamic>.from(desiredState);
        _isEditing = false;

        nameController.text = nameController.text.trim();
        emailController.text = emailController.text.trim();
        hireDateController.text = hireDateController.text.trim();
        fireDateController.text = fireDateController.text.trim();
        _notify();
        return true;
      }

      _lastSaveMessage = '사원 정보 저장에 실패했습니다.';
      return false;
    } on DioException catch (e) {
      if (_disposed) return false;

      final staleConflict = e.response?.statusCode == 409;
      final ambiguous = _isAmbiguousWriteFailure(e);
      if (staleConflict || ambiguous) {
        final reloaded = await _reloadEmployeeFromServer();
        if (reloaded) {
          _lastSaveMessage = staleConflict
              ? '다른 변경이 먼저 반영되어 최신 사원 정보를 다시 불러왔습니다.'
              : '저장 결과가 불명확해 서버의 현재 사원 정보를 다시 불러왔습니다.';
        } else {
          _lastSaveMessage =
              '최신 사원 정보를 다시 불러오지 못했습니다. 화면을 다시 열어 주세요.';
        }
      } else {
        _lastSaveMessage = e.message ?? '사원 정보 저장에 실패했습니다.';
      }
      return false;
    } catch (e) {
      debugPrint('사원 정보 저장 실패: $e');
      _lastSaveMessage = '사원 정보 저장에 실패했습니다.';
      return false;
    } finally {
      if (!_disposed) {
        _isSaving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    emailController.dispose();
    hireDateController.dispose();
    fireDateController.dispose();
    super.dispose();
  }
}
