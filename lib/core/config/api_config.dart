import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const String _prodUrl = 'https://app.dyinfotech.com';

  /// 빌드 시 `--dart-define=API_BASE_URL=...` 로 언제든 덮어쓸 수 있다.
  /// 실기기 디버깅(개발 PC 의 LAN IP), 스테이징 서버, CI 에서 사용.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // debug 만 로컬. release·profile 은 프로덕션.
    return kDebugMode ? _devUrl : _prodUrl;
  }

  static String get _devUrl {
    // Android 에뮬레이터에서 호스트 PC 의 localhost 는 10.0.2.2 로 잡힌다.
    // (실기기는 이 주소가 무의미하므로 API_BASE_URL 로 LAN IP 를 넘길 것)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
