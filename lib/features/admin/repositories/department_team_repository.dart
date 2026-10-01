import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

// 부서와 팀 관리에 필요한 서버 요청을 담당한다
class DepartmentTeamRepository {
  DepartmentTeamRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // 부서 조회와 변경 요청을 처리한다

  Future<List<Department>> fetchDepartments() async {
    final response = await _dio.authenticatedGet('/api/admin/departments');
    return (response.data as List)
        .map((json) => Department.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createDepartment(String departmentName) async {
    await _dio.authenticatedPost(
      '/api/admin/departments',
      data: DepartmentSaveRequest(departmentName: departmentName).toJson(),
    );
  }

  Future<void> updateDepartment(int departmentId, String departmentName) async {
    await _dio.authenticatedPut(
      '/api/admin/departments/$departmentId',
      data: DepartmentSaveRequest(departmentName: departmentName).toJson(),
    );
  }

  Future<void> deleteDepartment(int departmentId) async {
    await _dio.authenticatedDelete('/api/admin/departments/$departmentId');
  }

  // 팀 조회와 변경 요청을 처리한다

  Future<List<Team>> fetchTeams() async {
    final response = await _dio.authenticatedGet('/api/admin/teams');
    return (response.data as List)
        .map((json) => Team.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTeam(
    TeamCreateRequest request, {
    String? idempotencyKey,
  }) async {
    await _dio.authenticatedPost(
      '/api/admin/teams',
      data: request.toJson(),
      options: idempotencyKey == null
          ? null
          : Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
  }

  Future<void> updateTeam(int teamId, TeamUpdateRequest request) async {
    await _dio.authenticatedPut('/api/admin/teams/$teamId', data: request.toJson());
  }

  Future<void> deleteTeam(int teamId) async {
    await _dio.authenticatedDelete('/api/admin/teams/$teamId');
  }

  // 담당자 선택에 필요한 사원 조회를 처리한다

  Future<List<Employee>> searchEmployeesPage(
    String? keyword, {
    int page = 0,
    int size = 50,
  }) async {
    final q = keyword?.trim() ?? '';
    final response = await _dio.authenticatedGet(
      '/api/admin/employees/all',
      queryParameters: {
        if (q.isNotEmpty) 'searchParam': q,
        'page': page,
        'size': size,
      },
    );
    return (response.data as List)
        .map((json) => Employee.fromJson(json))
        .toList();
  }

  // 담당자 검색 결과를 서버 페이지 끝까지 수집한다
  Future<List<Employee>> searchEmployees(String? keyword) async {
    const pageSize = 100;
    const maxPages = 201;
    final result = <Employee>[];

    for (var page = 0; page < maxPages; page++) {
      final items = await searchEmployeesPage(
        keyword,
        page: page,
        size: pageSize,
      );
      result.addAll(items);
      if (items.length < pageSize) return result;
    }
    throw StateError('담당자 검색 결과가 조회 가능한 페이지 한도를 초과했습니다.');
  }
}
