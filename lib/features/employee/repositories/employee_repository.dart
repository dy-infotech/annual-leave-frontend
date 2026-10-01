import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

// 내 정보 변경에 필요한 서버 요청을 담당한다
class EmployeeRepository {
  EmployeeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // 현재 비밀번호를 확인하고 새 비밀번호로 변경한다
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.authenticatedPatch(
      '/api/employees/me/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  // 현재 사용자의 이메일을 변경한다
  Future<void> changeEmail(String email) async {
    await _dio.authenticatedPatch('/api/employees/me/email', data: {"email": email});
  }
}
