# 02. 개발 환경 / 빌드 · 실행

## 2.1 사전 요구사항

| 항목 | 버전/비고 |
|---|---|
| Flutter SDK | stable 채널(`.metadata` 참고), Dart `>=3.5.0 <4.0.0` |
| 플랫폼 도구 | Android Studio/Xcode(각 플랫폼 빌드 시), Chrome(Web 실행 시) |
| 백엔드 | 로컬 또는 배포된 `annual-leave-backend` 인스턴스([백엔드 02. 개발 환경](../../annual-leave-backend/docs/02-dev-environment.md) 참조) |

## 2.2 초기 셋업

```bash
flutter pub get
```

`flutter_launcher_icons`(devDependency)는 아이콘 재생성 시에만 필요:
```bash
flutter pub run flutter_launcher_icons
```

## 2.3 로컬 백엔드에 연결하기 (baseUrl 전환)

**환경변수가 아니라 코드 직접 수정**이 필요합니다. `lib/config/api_config.dart`를 열어 플랫폼별 `return` 문의 주석을 교체하세요.

```dart
static String get baseUrl {
  if (kIsWeb) {
    // return 'http://localhost:8080';        // ← 로컬 개발 시 이 줄의 주석 해제
    return 'https://api.dyinfotech.com';       // ← 운영 기본값(현재 활성)
  }
  if (Platform.isAndroid) {
    return 'https://api.dyinfotech.com';
    // return 'http://10.0.2.2:8080';          // 에뮬레이터에서 로컬 PC 접근 시
    // return 'http://192.168.0.5:8080';       // 실기기에서 같은 네트워크의 PC 접근 시(IP 직접 수정 필요)
  }
  return 'http://localhost:8080';               // iOS 시뮬레이터(현재 활성)
  // return 'http://192.168.0.5:8080';          // iOS 실기기
}
```

> ⚠️ 이 파일은 gitignore 대상이 아니므로, 로컬 개발용으로 값을 바꾼 뒤 **커밋 시 원복하지 않으면 운영 빌드가 로컬 서버를 바라보게 됩니다.** 주의해서 되돌리세요.

## 2.4 `.env`는 사용되지 않습니다 (죽은 설정)

루트에 `.env` 파일이 존재합니다:
```
USE_NGROK=true
NGROK_URL=https://primsie-alda-sprawly.ngrok-free.dev
```
하지만 `pubspec.yaml`에서 `flutter_dotenv` 의존성이 **주석 처리**되어 있고, `lib/` 어디에서도 `.env`를 읽는 코드가 없습니다. **이 파일은 현재 아무 효과가 없습니다.** (과거 `test-web-deploy` 브랜치에서 ngrok 터널 실험을 위해 도입했던 흔적만 남은 상태입니다.) baseUrl을 바꾸려면 위 §2.3처럼 `api_config.dart`를 직접 수정해야 합니다.

## 2.5 실행 명령

```bash
# 연결된 디바이스 목록 확인
flutter devices

# 실행 (디바이스 선택)
flutter run -d <deviceId>

# Web으로 실행 (Chrome)
flutter run -d chrome
```

## 2.6 빌드 명령

| 플랫폼 | 명령 | 산출물 |
|---|---|---|
| Android(APK) | `flutter build apk` | `build/app/outputs/flutter-apk/app-release.apk` |
| Android(AAB, 스토어용) | `flutter build appbundle` | `build/app/outputs/bundle/release/app-release.aab` |
| iOS | `flutter build ios` | Xcode로 서명/배포 필요 |
| Web | `flutter build web` | `build/web/` (정적 파일, Vercel 등에 배포) |

## 2.7 린트 / 테스트

```bash
flutter analyze   # flutter_lints 규칙 기반 정적 분석(커스텀 규칙 없음)
flutter test       # 테스트 실행
```

> ⚠️ **테스트 코드가 없습니다.** `flutter_test`가 devDependency로 있지만 `test/` 디렉토리 자체가 저장소에 존재하지 않습니다. `flutter test`를 실행해도 검증되는 것이 없습니다.

## 2.8 IDE 설정

- VS Code(`.vscode/`는 gitignore) 또는 Android Studio/IntelliJ + Flutter/Dart 플러그인 사용.
- `analysis_options.yaml`은 `package:flutter_lints/flutter.yaml`만 include하며 커스텀 규칙은 비어 있습니다.

## 2.9 주의점 / 제안

- baseUrl이 코드에 하드코딩되어 있어 **환경별 빌드(`--dart-define` 또는 flavor)** 도입을 검토하면 로컬/운영 전환 실수를 줄일 수 있습니다.
- `.env`/`flutter_dotenv` 죽은 설정은 혼란을 줄 수 있으므로 정리(제거 또는 실제 연결) 필요.
- 테스트 부재 — 최소한 모델의 `fromJson`/`toJson` 단위 테스트부터 도입 권장.
