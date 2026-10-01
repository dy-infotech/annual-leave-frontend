import 'package:dio/dio.dart';

/// 웹이 아닌 플랫폼용 no-op. (브라우저 쿠키 설정이 필요 없다)
void configureBrowserCredentials(Dio dio) {}
