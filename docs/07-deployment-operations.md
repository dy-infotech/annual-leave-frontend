# 07. 배포 / 운영

> ⚠️ 이 저장소에는 커밋된 배포 자동화 설정이 없습니다(`vercel.json`, `next.config`, `.github/workflows`, Fastlane 등 부재). 이 문서는 "확인 가능한 사실"과 "추정 사항"(명시 표기), "개선 제안"으로 구성됩니다.

## 7.1 앱 식별 정보

- 패키지명: `annual_leave_frontend`
- 버전: `1.0.0+1`(`pubspec.yaml`, `version`) — `버전이름+빌드번호` 형식(Android `versionName`+`versionCode`, iOS `CFBundleShortVersionString`+`CFBundleVersion`에 매핑).
- 앱 아이콘: `flutter_launcher_icons` 설정(`pubspec.yaml`)이 `assets/icon/app_icon.png`를 소스로 Android/iOS 아이콘을 생성(`min_sdk_android: 21`, `remove_alpha_ios: true`).
  ```bash
  flutter pub run flutter_launcher_icons
  ```

## 7.2 플랫폼별 빌드

| 플랫폼 | 명령 | 후속 작업 |
|---|---|---|
| Android(APK) | `flutter build apk` | 사이드로드 또는 내부 배포 |
| Android(AAB) | `flutter build appbundle` | Play Console 업로드(서명 키 필요, 저장소에 서명 설정 없음 — 로컬/별도 관리로 추정) |
| iOS | `flutter build ios` | Xcode에서 서명·아카이브 후 App Store Connect 업로드 |
| Web | `flutter build web` | 산출물(`build/web/`)을 정적 호스팅에 배포 |

빌드 전 [02. 개발 환경 §2.3](02-dev-environment.md#23-로컬-백엔드에-연결하기-baseurl-전환)에서 baseUrl이 운영 값(`https://api.dyinfotech.com`)으로 되어 있는지 반드시 확인하세요(로컬 개발용으로 바꿨다가 원복을 잊으면 운영 빌드가 로컬 서버를 바라봅니다).

## 7.3 Web 배포 (Vercel) — 추정

- 알려진 배포 주소: `annual-leave-frontend.vercel.app`.
- 저장소에는 Vercel 관련 설정 파일이 전혀 없습니다. 대신 `test-web-deploy`라는 별도 브랜치에 다음 커밋이 남아 있어, **웹 배포 테스트 과정의 흔적**으로 추정됩니다:
  - `chore: dotenv 패키지 추가`
  - `chore: 초기화 순서 수정`
  - `chore: 웹 배포 테스트용 터널링 URL 적용`
  - `fix: ngrok 경고 페이지 우회 헤더 추가`
- **추정되는 배포 방식**: `flutter build web`으로 생성한 `build/web/` 정적 산출물을 Vercel 대시보드에서 프로젝트로 연결해 수동/반자동 배포. Git push 시 자동 빌드되는 CI 연동 여부는 **저장소 코드만으로는 확인 불가**(Vercel 프로젝트 설정 대시보드 확인 필요).
- FCM/Firebase 관련 웹 설정(서비스워커 등)은 코드베이스에 없습니다([01 §1.6](01-system-architecture.md#16-백엔드와의-기능적-연동-범위) 참조 — FCM 자체가 미구현).

## 7.4 CI/CD

- `.github/workflows/` 없음 — GitHub Actions 등 CI 파이프라인이 구성되어 있지 않습니다.
- `.github/`에는 `PULL_REQUEST_TEMPLATE.md`, `ISSUE_TEMPLATE/`만 존재(협업 템플릿 용도).
- 즉 `flutter analyze`/`flutter test`/`flutter build`가 PR·머지 시점에 자동 검증되지 않습니다.

## 7.5 브랜치 전략 (관찰 사실)

이슈 번호 기반 네이밍 컨벤션을 사용 중입니다: `main`, `develop`, `feature/<issue-number>-<slug>`(예: `feature/58-calendar-mark-requested-dates`), `fix/<issue-number>-<slug>`, `chore/<issue-number>-<slug>`, `refactor/<issue-number>-<slug>`(예: `refactor/62-mvvm-pattern`). `test-web-deploy`는 일반 기능 브랜치가 아닌 배포 실험용으로 보입니다.

## 7.6 운영 시 필요한 사전 준비

| 항목 | 필요 여부 |
|---|---|
| 백엔드 API 접근 | `https://api.dyinfotech.com`(운영) 가용성 필요 — [백엔드 03. 배포/운영](../../annual-leave-backend/docs/03-deployment-operations.md) 참조 |
| Android 서명 키 | 스토어 배포 시 필요(저장소에 keystore 설정 없음 — 별도 보안 채널로 관리 필요) |
| iOS 인증서/프로비저닝 | App Store 배포 시 Xcode/Apple Developer 계정 필요 |
| Vercel 프로젝트 접근 권한 | Web 배포/재배포 시 필요(대시보드 직접 확인 필요) |

## 7.7 주의점 / 제안

1. **CI 도입**: `flutter analyze` + `flutter build web/apk`를 최소한 PR 시점에 자동 실행하는 GitHub Actions 워크플로 추가 권장.
2. **Web 배포 파이프라인 명문화**: Vercel 프로젝트의 실제 빌드 설정(빌드 커맨드, 출력 디렉토리, 자동 배포 트리거 여부)을 Vercel 대시보드에서 확인해 이 문서에 반영 필요(현재는 추정치).
3. **환경별 빌드**: baseUrl 하드코딩([02 §2.3](02-dev-environment.md#23-로컬-백엔드에-연결하기-baseurl-전환))을 CI/CD와 연계하려면 `--dart-define`이나 flavor 기반 환경 분리가 선행되어야 합니다.
4. **`.env`/ngrok 잔재 정리**: 죽은 설정([02 §2.4](02-dev-environment.md#24-env는-사용되지-않습니다-죽은-설정))이 배포 관련 브랜치에 남아있어 향후 혼란을 줄 수 있으므로 정리 권장.
5. **서명 키/인증서 관리 문서화**: 현재 저장소에 관련 정보가 전혀 없어, 실제 스토어 배포 담당자에게 별도로 인수받아야 합니다.
