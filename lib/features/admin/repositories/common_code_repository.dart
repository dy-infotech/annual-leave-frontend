import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// 관리자 기초 코드 조회 API.
///
/// 응답 형태(팀/부서/직급 목록 등)의 해석은 화면별 요구가 달라
/// 원본 Map을 그대로 돌려주고 호출부에서 필요한 키를 꺼내 쓴다.
class CommonCodeRepository {
  final Dio _dio;

  CommonCodeRepository({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  /// 기초 코드 조회. GET /api/admin/auth/common
  Future<Map<String, dynamic>> fetchCommonCodes() async {
    final response = await _dio.get('/api/admin/auth/common');
    return response.data as Map<String, dynamic>;
  }
}
