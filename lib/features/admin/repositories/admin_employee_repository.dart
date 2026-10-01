import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:dio/dio.dart';

/// 관리자용 사원 정보 API 호출 모음. (ADM001, ADM004 계열 화면에서 사용)
class AdminEmployeeRepository {
  AdminEmployeeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  /// 사원 목록 조회. GET /api/admin/employees/all
  ///
  /// 검색어가 비어 있으면 쿼리 파라미터 없이 전체를 조회한다. (기존 화면과 동일)
  Future<List<Employee>> fetchEmployees({String? searchParam}) async {
    final response = await _dio.get(
      '/api/admin/employees/all',
      queryParameters: searchParam == null || searchParam.isEmpty
          ? null
          : {'searchParam': searchParam},
    );
    return (response.data as List)
        .map((json) => Employee.fromJson(json))
        .toList();
  }

  Future<List<Employee>> fetchEmployeesPage({
    String? searchParam,
    String? team,
    bool? registered,
    int page = 0,
    int size = 50,
  }) async {
    final normalizedSearch = searchParam?.trim();
    final normalizedTeam = team?.trim();
    final response = await _dio.get(
      '/api/admin/employees/all',
      queryParameters: {
        if (normalizedSearch != null && normalizedSearch.isNotEmpty)
          'searchParam': normalizedSearch,
        if (normalizedTeam != null && normalizedTeam.isNotEmpty)
          'team': normalizedTeam,
        if (registered != null) 'registered': registered,
        'page': page,
        'size': size,
      },
    );
    return (response.data as List)
        .map((json) => Employee.fromJson(json))
        .toList();
  }

  /// 사원 정보 수정. PUT /api/admin/employees/{employeeNumber}
  ///
  /// 호출부가 상태코드로 성공 여부를 판단하므로 statusCode를 그대로 돌려준다.
  Future<int?> updateEmployee(
      String employeeNumber, Map<String, dynamic> data) async {
    final response =
        await _dio.put('/api/admin/employees/$employeeNumber', data: data);
    return response.statusCode;
  }

  /// 관리팀 최종 상태를 compare-and-set 방식으로 저장한다.
  Future<int?> updateManagedTeams(
    String employeeNumber, {
    required List<String> expectedManagedTeams,
    required List<String> managedTeams,
  }) async {
    final response = await _dio.put(
      '/api/admin/employees/$employeeNumber/managed-teams',
      data: {
        'expectedManagedTeams': expectedManagedTeams,
        'managedTeams': managedTeams,
      },
    );
    return response.statusCode;
  }
}
