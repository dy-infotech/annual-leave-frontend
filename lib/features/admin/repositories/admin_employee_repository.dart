import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:dio/dio.dart';

/// 관리자용 사원 정보 API 호출 모음. (ADM001, ADM004 계열 화면에서 사용)
class AdminEmployeeRepository {
  AdminEmployeeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  static const int _pageSize = 100;
  static const int _maxPages = 201;

  /// 기존 화면은 전체 결과를 기대하므로 bounded 서버 page를 끝까지 수집한다.
  /// 필터가 있으면 서버에 함께 전달해 불필요한 row 전송을 줄인다.
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

  /// 사원 정보 수정. PUT /api/admin/employees/{employeeNumber}
  ///
  /// 호출부가 상태코드로 성공 여부를 판단하므로 statusCode를 그대로 돌려준다.
  Future<int?> updateEmployee(
      String employeeNumber, Map<String, dynamic> data) async {
    final response =
        await _dio.authenticatedPut('/api/admin/employees/$employeeNumber', data: data);
    return response.statusCode;
  }

  /// 관리팀 최종 상태를 compare-and-set 방식으로 저장한다.
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
