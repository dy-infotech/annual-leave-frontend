/// 플랫폼별 Dio 쿠키 전송 설정을 선택한다.
///
/// 웹(`dart.library.html`)에서는 refresh 쿠키가 요청에 실리도록 설정하고,
/// 그 외 플랫폼(모바일/테스트)에서는 아무 설정도 하지 않는다.
export 'browser_credentials_stub.dart'
    if (dart.library.html) 'browser_credentials_web.dart';
