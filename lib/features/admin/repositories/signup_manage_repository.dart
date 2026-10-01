import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';

// 관리자 사용자 등록 요청을 담당한다
class SignupManageRepository {
  SignupManageRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  // 입력된 사용자 정보를 서버에 등록한다
  Future<void> registerUser(AdminAuthRegisterRequest request) async {
    await _dio.authenticatedPost('/api/admin/auth/register', data: request.toJson());
  }
}
