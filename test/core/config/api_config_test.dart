import 'package:annual_leave_frontend/core/config/api_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride, kDebugMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiConfig.baseUrl', () {
    test('스킴과 호스트를 갖춘 URL을 돌려준다', () {
      final uri = Uri.parse(ApiConfig.baseUrl);

      expect(uri.hasScheme, isTrue);
      expect(uri.host, isNotEmpty);
      expect(ApiConfig.baseUrl, isNot(endsWith('/')));
    });

    test('안드로이드 디버그에서는 에뮬레이터용 호스트 주소를 쓴다', () {
      // 안드로이드 에뮬레이터에서 호스트 PC의 localhost는 10.0.2.2로 잡힌다.
      if (const String.fromEnvironment('API_BASE_URL').isNotEmpty) return;

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(kDebugMode, isTrue);
      expect(ApiConfig.baseUrl, 'http://10.0.2.2:8080');
    });

    test('안드로이드가 아닌 디버그 환경에서는 localhost를 쓴다', () {
      if (const String.fromEnvironment('API_BASE_URL').isNotEmpty) return;

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(ApiConfig.baseUrl, 'http://localhost:8080');
    });

    test('dart-define으로 넘긴 값이 있으면 그 값이 우선한다', () {
      const override = String.fromEnvironment('API_BASE_URL');

      if (override.isNotEmpty) {
        expect(ApiConfig.baseUrl, override);
      }
    });

    test('여러 번 읽어도 같은 값이다', () {
      expect(ApiConfig.baseUrl, ApiConfig.baseUrl);
    });
  });
}
