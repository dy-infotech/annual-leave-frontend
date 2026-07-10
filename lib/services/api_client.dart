import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // 요청마다, 저장된 JWT를 자동으로 Authorization 헤더에 할당
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException error, handler) {
        // 공통 에러 메시지 추출 후 원본 예외에 실어 상위로 전달
        return handler.next(error.copyWith(message: _extractErrorMessage(error)));
      },
    ));
  }

  // 서버가 내려준 메시지를 우선 사용하고, 없으면 예외 유형에 맞는
  // 사람이 읽을 수 있는 메시지로 대체한다.
  static String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      final serverMessage = (data['message'] as String).trim();
      if (serverMessage.isNotEmpty) {
        return serverMessage;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.';
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return '네트워크 연결을 확인해주세요.';
      default:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          return '요청을 처리하지 못했습니다. (오류 코드: $statusCode)';
        }
        return '알 수 없는 오류가 발생했습니다.';
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
