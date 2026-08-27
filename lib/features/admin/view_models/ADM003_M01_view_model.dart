import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/repositories/department_team_repository.dart';

/// 부서 및 팀 관리 화면(ADM003_M01)의 ViewModel.
class DepartmentTeamViewModel extends ChangeNotifier {
  DepartmentTeamViewModel({DepartmentTeamRepository? repository})
      : _repository = repository ?? DepartmentTeamRepository();

  final DepartmentTeamRepository _repository;

  List<Department> _departments = [];
  List<Team> _teams = [];

  // 탭별로 목록이 독립적이므로 로딩/에러 상태도 탭별로 분리한다.
  bool _isDeptLoading = false;
  bool _isTeamLoading = false;
  String? _deptError;
  String? _teamError;

  /// 팀 탭의 부서 필터. null 이면 전체.
  int? _teamFilterDeptId;

  List<Department> get departments => _departments;
  List<Team> get teams => _teams;
  bool get isDeptLoading => _isDeptLoading;
  bool get isTeamLoading => _isTeamLoading;
  String? get deptError => _deptError;
  String? get teamError => _teamError;
  int? get teamFilterDeptId => _teamFilterDeptId;

  void setTeamFilter(int? departmentId) {
    _teamFilterDeptId = departmentId;
    notifyListeners();
  }

  List<Team> teamsOfDepartment(int departmentId) =>
      _teams.where((t) => t.departmentId == departmentId).toList();

  // ---------------------------------------------------------------- 조회

  Future<void> refreshAll() =>
      Future.wait([fetchDepartments(), fetchTeams()]);

  // 1. 부서 목록 조회
  Future<void> fetchDepartments() async {
    _isDeptLoading = true;
    _deptError = null;
    notifyListeners();

    try {
      _departments = await _repository.fetchDepartments();
    } catch (e) {
      debugPrint('부서 목록 조회 실패: $e');
      _deptError = messageOf(e, '부서 목록을 불러오지 못했습니다.');
    } finally {
      _isDeptLoading = false;
      notifyListeners();
    }
  }

  // 2. 팀 목록 조회
  Future<void> fetchTeams() async {
    _isTeamLoading = true;
    _teamError = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchTeams();
      _teams = fetched;
      // 필터로 걸어둔 부서가 사라졌으면 전체로 되돌린다.
      if (_teamFilterDeptId != null &&
          !fetched.any((t) => t.departmentId == _teamFilterDeptId)) {
        _teamFilterDeptId = null;
      }
    } catch (e) {
      debugPrint('팀 목록 조회 실패: $e');
      _teamError = messageOf(e, '팀 목록을 불러오지 못했습니다.');
    } finally {
      _isTeamLoading = false;
      notifyListeners();
    }
  }

  /// ApiClient 인터셉터가 응답 body 의 message 를 DioException.message 로 옮겨 둔다.
  /// 서버가 준 사유가 있으면 그것을 쓰고, 없으면 기본 문구를 쓴다.
  String messageOf(Object error, String fallback) {
    if (error is DioException) {
      final message = error.message;
      if (message != null && message.trim().isNotEmpty) return message;
    }
    return fallback;
  }

  // ---------------------------------------------------------------- 부서 저장/삭제

  /// 부서 등록/이름 변경. 성공 시 null, 실패 시 보여줄 메시지를 반환한다.
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

  /// 부서 삭제. 성공 시 null, 실패 시 보여줄 메시지를 반환한다.
  Future<String?> deleteDepartment(Department dept) async {
    try {
      await _repository.deleteDepartment(dept.departmentId);
      return null;
    } catch (e) {
      debugPrint('부서 삭제 실패: $e');
      return messageOf(e, '부서 삭제에 실패했습니다.');
    }
  }

  // ---------------------------------------------------------------- 팀 저장/삭제

  /// 팀 등록. 성공 시 null, 실패 시 보여줄 메시지를 반환한다.
  Future<String?> submitTeamCreate({
    required String teamName,
    required int managerId,
    required int departmentId,
    int? parentTeamId,
  }) async {
    try {
      await _repository.createTeam(TeamCreateRequest(
        teamName: teamName,
        projectManagerId: managerId,
        departmentId: departmentId,
        parentTeamId: parentTeamId,
      ));
      return null;
    } catch (e) {
      debugPrint('팀 등록 실패: $e');
      return messageOf(e, '팀 등록에 실패했습니다.');
    }
  }

  /// 팀 수정. 바뀐 필드만 보내고 나머지는 서버가 기존 값을 유지한다.
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

  /// 팀 삭제. 성공 시 null, 실패 시 보여줄 메시지를 반환한다.
  Future<String?> deleteTeam(Team team) async {
    try {
      await _repository.deleteTeam(team.teamId);
      return null;
    } catch (e) {
      debugPrint('팀 삭제 실패: $e');
      return messageOf(e, '팀 삭제에 실패했습니다.');
    }
  }

  // ---------------------------------------------------------------- 사원

  Future<List<Employee>> searchEmployees(String? keyword) =>
      _repository.searchEmployees(keyword);
}
