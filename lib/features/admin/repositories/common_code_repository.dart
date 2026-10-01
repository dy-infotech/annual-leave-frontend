import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

// 관리자 화면에서 사용하는 기초 코드를 조회한다
class CommonCodeRepository {
  final Dio _dio;

  CommonCodeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  // 기초 코드 응답을 원본 형태로 반환한다
  Future<Map<String, dynamic>> fetchCommonCodes() async {
    final response = await _dio.authenticatedGet('/api/admin/auth/common');
    return response.data as Map<String, dynamic>;
  }
}
