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
}
