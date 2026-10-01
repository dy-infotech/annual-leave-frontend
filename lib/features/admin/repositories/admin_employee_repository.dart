import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:dio/dio.dart';

// 관리자용 사원 조회와 수정 요청을 담당한다
class AdminEmployeeRepository {
  AdminEmployeeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  static const int _pageSize = 100;
  static const int _maxPages = 201;

  // 화면에 필요한 사원 목록을 서버 페이지 끝까지 수집한다
  Future<List<Employee>> fetchEmployees({
    String? searchParam,
    String? team,
    bool? registered,
  }) async {
    final result = <Employee>[];
    for (var page = 0; page < _maxPages; page++) {
      final items = await fetchEmployeesPage(
        searchParam: searchParam,
        team: team,
        registered: registered,
        page: page,
        size: _pageSize,
      );
      result.addAll(items);
      if (items.length < _pageSize) return result;
    }
    throw StateError('사원 목록이 조회 가능한 페이지 한도를 초과했습니다.');
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
    final response = await _dio.authenticatedGet(
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

  // 사원 정보를 수정하고 응답 상태를 그대로 반환한다
  Future<int?> updateEmployee(
      String employeeNumber, Map<String, dynamic> data) async {
    final response =
        await _dio.authenticatedPut('/api/admin/employees/$employeeNumber', data: data);
    return response.statusCode;
  }

  // 마지막 조회 상태를 기준으로 담당 팀 변경을 저장한다
  Future<int?> updateManagedTeams(
    String employeeNumber, {
    required List<String> expectedManagedTeams,
    required List<String> managedTeams,
  }) async {
    final response = await _dio.authenticatedPut(
      '/api/admin/employees/$employeeNumber/managed-teams',
      data: {
        'expectedManagedTeams': expectedManagedTeams,
        'managedTeams': managedTeams,
      },
    );
    return response.statusCode;
  }
}
