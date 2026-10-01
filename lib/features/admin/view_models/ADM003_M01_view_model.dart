import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/department_team_repository.dart';

// 부서와 팀 목록 및 변경 요청 상태를 관리한다
class DepartmentTeamViewModel extends ChangeNotifier {
  DepartmentTeamViewModel({DepartmentTeamRepository? repository})
      : _repository = repository ?? DepartmentTeamRepository();

  final DepartmentTeamRepository _repository;

  List<Department> _departments = [];
  List<Team> _teams = [];

  bool _isDeptLoading = false;
  bool _isTeamLoading = false;
  String? _deptError;
  String? _teamError;
  int _deptRequestSeq = 0;
  int _teamRequestSeq = 0;
  bool _disposed = false;

  // 선택한 부서 기준으로 팀 목록을 필터링한다
  int? _teamFilterDeptId;

  List<Department> get departments => _departments;
  List<Team> get teams => _teams;
  bool get isDeptLoading => _isDeptLoading;
  bool get isTeamLoading => _isTeamLoading;
  String? get deptError => _deptError;
  String? get teamError => _teamError;
  int? get teamFilterDeptId => _teamFilterDeptId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setTeamFilter(int? departmentId) {
    _teamFilterDeptId = departmentId;
    _notify();
  }

  List<Team> teamsOfDepartment(int departmentId) =>
      _teams.where((t) => t.departmentId == departmentId).toList();

  // 부서와 팀 목록을 함께 새로고침한다
  Future<void> refreshAll() =>
      Future.wait([fetchDepartments(), fetchTeams()]);

  Future<void> fetchDepartments() async {
    final seq = ++_deptRequestSeq;
    _isDeptLoading = true;
    _deptError = null;
    _notify();

    try {
      final fetched = await _repository.fetchDepartments();
      if (_disposed || seq != _deptRequestSeq) return;
      _departments = fetched;
    } catch (e) {
      if (_disposed || seq != _deptRequestSeq) return;
      debugPrint('부서 목록 조회 실패: $e');
      _deptError = messageOf(e, '부서 목록을 불러오지 못했습니다.');
    } finally {
      if (!_disposed && seq == _deptRequestSeq) {
        _isDeptLoading = false;
        _notify();
      }
    }
  }

  Future<void> fetchTeams() async {
    final seq = ++_teamRequestSeq;
    _isTeamLoading = true;
    _teamError = null;
    _notify();

    try {
      final fetched = await _repository.fetchTeams();
      if (_disposed || seq != _teamRequestSeq) return;

      _teams = fetched;
      if (_teamFilterDeptId != null &&
          !fetched.any((t) => t.departmentId == _teamFilterDeptId)) {
        _teamFilterDeptId = null;
      }
    } catch (e) {
      if (_disposed || seq != _teamRequestSeq) return;
      debugPrint('팀 목록 조회 실패: $e');
      _teamError = messageOf(e, '팀 목록을 불러오지 못했습니다.');
    } finally {
      if (!_disposed && seq == _teamRequestSeq) {
        _isTeamLoading = false;
        _notify();
      }
    }
  }

  String messageOf(Object error, String fallback) {
    if (error is DioException) {
      final message = error.message;
      if (message != null && message.trim().isNotEmpty) return message;
    }
    return fallback;
  }

  // 기존 부서 여부에 따라 생성 또는 수정을 요청한다
  Future<String?> submitDepartment(Department? origin, String name) async {
    try {
      if (origin == null) {
        await _repository.createDepartment(name);
      } else {
        await _repository.updateDepartment(origin.departmentId, name);
      }
      return null;
    } catch (e) {
      debugPrint('부서 저장 실패: $e');
      return messageOf(
          e, origin == null ? '부서 등록에 실패했습니다.' : '부서 수정에 실패했습니다.');
    }
  }

  // 부서 삭제 후 전체 조직 목록을 다시 조회한다
  Future<String?> deleteDepartment(Department dept) async {
    try {
      await _repository.deleteDepartment(dept.departmentId);
      return null;
    } catch (e) {
      debugPrint('부서 삭제 실패: $e');
      return messageOf(e, '부서 삭제에 실패했습니다.');
    }
  }

  // 팀 생성 후 전체 조직 목록을 다시 조회한다
  Future<String?> submitTeamCreate({
    required String teamName,
    required int managerId,
    required int departmentId,
    int? parentTeamId,
    String? idempotencyKey,
  }) async {
    try {
      await _repository.createTeam(
        TeamCreateRequest(
          teamName: teamName,
          projectManagerId: managerId,
          departmentId: departmentId,
          parentTeamId: parentTeamId,
        ),
        idempotencyKey: idempotencyKey,
      );
      return null;
    } catch (e) {
      debugPrint('팀 등록 실패: $e');
      return messageOf(e, '팀 등록에 실패했습니다.');
    }
  }

  // 팀 수정 후 전체 조직 목록을 다시 조회한다
  Future<String?> submitTeamUpdate(
    Team origin, {
    required String teamName,
    int? departmentId,
    int? parentTeamId,
    int? managerId,
  }) async {
    final request = TeamUpdateRequest(
      teamName: teamName != origin.teamName ? teamName : null,
      departmentId: departmentId != origin.departmentId ? departmentId : null,
      parentTeamId:
          parentTeamId != null && parentTeamId != origin.parentTeamId
              ? parentTeamId
              : null,
      projectManagerId: managerId,
    );
    if (request.isEmpty) return null;

    try {
      await _repository.updateTeam(origin.teamId, request);
      return null;
    } catch (e) {
      debugPrint('팀 수정 실패: $e');
      return messageOf(e, '팀 수정에 실패했습니다.');
    }
  }

  // 팀 삭제 후 전체 조직 목록을 다시 조회한다
  Future<String?> deleteTeam(Team team) async {
    try {
      await _repository.deleteTeam(team.teamId);
      return null;
    } catch (e) {
      debugPrint('팀 삭제 실패: $e');
      return messageOf(e, '팀 삭제에 실패했습니다.');
    }
  }

  Future<List<Employee>> searchEmployees(String? keyword) =>
      _repository.searchEmployees(keyword);

  Future<List<Employee>> searchEmployeesPage(
    String? keyword, {
    int page = 0,
    int size = 50,
  }) =>
      _repository.searchEmployeesPage(
        keyword,
        page: page,
        size: size,
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
