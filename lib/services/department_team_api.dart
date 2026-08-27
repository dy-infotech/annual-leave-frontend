import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';

/// 부서/팀 관리 API 호출 모음. (docs/api-spec-department-team.md 참고)
///
/// 전 엔드포인트가 대표이사 전용이며, 그 외 계정은 403 이 반환된다.
/// 에러 응답의 message 는 ApiClient 인터셉터가 DioException.message 로 옮겨 두므로
/// 호출부는 그것을 그대로 사용자에게 보여주면 된다.
///
/// 위젯 테스트에서는 [instance] 를 페이크 구현으로 교체한다.
class DepartmentTeamApi {
  DepartmentTeamApi();

  static DepartmentTeamApi instance = DepartmentTeamApi();

  // ------------------------------------------------------------ 부서

  Future<List<Department>> fetchDepartments() async {
    final response = await ApiClient().dio.get('/api/admin/departments');
    return (response.data as List)
        .map((json) => Department.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDepartment(String departmentName) async {
    await ApiClient().dio.post(
          '/api/admin/departments',
          data: DepartmentSaveRequest(departmentName: departmentName).toJson(),
        );
  }

  Future<void> updateDepartment(int departmentId, String departmentName) async {
    await ApiClient().dio.put(
          '/api/admin/departments/$departmentId',
          data: DepartmentSaveRequest(departmentName: departmentName).toJson(),
        );
  }

  Future<void> deleteDepartment(int departmentId) async {
    await ApiClient().dio.delete('/api/admin/departments/$departmentId');
  }

  // ------------------------------------------------------------ 팀

  Future<List<Team>> fetchTeams() async {
    final response = await ApiClient().dio.get('/api/admin/teams');
    return (response.data as List)
        .map((json) => Team.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTeam(TeamCreateRequest request) async {
    await ApiClient().dio.post('/api/admin/teams', data: request.toJson());
  }

  Future<void> updateTeam(int teamId, TeamUpdateRequest request) async {
    await ApiClient().dio.put('/api/admin/teams/$teamId', data: request.toJson());
  }

  Future<void> deleteTeam(int teamId) async {
    await ApiClient().dio.delete('/api/admin/teams/$teamId');
  }

  // ------------------------------------------------------------ 사원

  /// 담당자 선택용 사원 검색. 검색어는 사번 또는 성명 부분 일치.
  Future<List<Employee>> searchEmployees(String? keyword) async {
    final q = keyword?.trim() ?? '';
    final response = await ApiClient().dio.get(
          '/api/admin/employees/all',
          queryParameters: q.isEmpty ? null : {'searchParam': q},
        );
    return (response.data as List)
        .map((json) => Employee.fromJson(json))
        .toList();
  }
}
