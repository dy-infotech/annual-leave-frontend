import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:dio/dio.dart';

/// 사용자 등록 관리 API. (ADM002 화면에서 사용)
class SignupManageRepository {
  SignupManageRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  /// 신규 사용자 등록. POST /api/admin/auth/register
  Future<void> registerUser(AdminAuthRegisterRequest request) async {
    await _dio.post('/api/admin/auth/register', data: request.toJson());
  }
}
