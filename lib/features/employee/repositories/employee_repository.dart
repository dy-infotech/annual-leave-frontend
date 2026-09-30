import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// 내 정보 관련 API 호출 모음. (EMP001 화면에서 사용)
class EmployeeRepository {
  EmployeeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  /// 비밀번호 변경. PATCH /api/employees/me/password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch(
      '/api/employees/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// 이메일 변경. PATCH /api/employees/me/email
  Future<void> changeEmail(String email) async {
    await _dio.patch('/api/employees/me/email', data: {"email": email});
  }
}
