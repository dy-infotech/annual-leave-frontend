import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// 웹에서 모든 요청에 쿠키(refresh 토큰)를 포함하도록 `withCredentials`를 켠다.
/// 서버의 CORS 설정이 자격 증명 허용(Allow-Credentials)이어야 동작한다.
void configureBrowserCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
