# 07. 배포 / 운영

## 7.1 CI

`.github/workflows/ci.yml`은 `develop_v2.0` push와 지정된 PR에서 실행됩니다.

주요 단계:

1. Flutter stable 설치 및 cache 사용
2. `flutter pub get`
3. `flutter analyze --no-fatal-infos --no-fatal-warnings`
4. `flutter test`

기존 warning/info 정리 전까지 CI는 analyzer error를 차단하는 수준으로 운용합니다.

## 7.2 Release Web 배포

`.github/workflows/deploy.yml`은 `release` push 또는 수동 실행으로 동작합니다. 배포 전에 다시 의존성 설치, 정적 분석, 전체 테스트, `flutter build web --release`를 수행합니다.

빌드 산출물은 먼저 서버의 `/tmp/flutter-deploy`에 업로드합니다. 서버에서는 다음 순서로 전환합니다.

1. `/opt/annual-leave/front/web.next`에 신규 산출물을 staging
2. `index.html` 존재 여부와 파일 유무 검증
3. 현재 `web`을 `web.prev`로 이동
4. `web.next`를 `web`으로 전환
5. 전환 중 오류가 나면 ERR trap으로 기존 `web.prev` 복원
6. 성공하면 이전 버전과 임시 staging 정리

따라서 기존의 `web/*` 선삭제 후 복사 방식처럼 복사 도중 서비스 파일이 반쯤 남는 배포를 피합니다.

## 7.3 운영 API

운영 API 주소는 `ApiConfig`의 현재 환경 설정을 따릅니다. release 전에는 운영 Backend를 가리키는지 확인해야 합니다.

Backend release는 별도 저장소의 CD가 담당하며 Oracle v2 schema validation과 HTTP readiness 확인을 수행합니다.

## 7.4 FCM

FCM은 현재 구현되어 있습니다. 관리자 대시보드에서 token/topic 동기화를 수행하고, 로그아웃 시 서버와 클라이언트의 FCM token을 정리합니다.

브라우저/플랫폼 알림 권한 거부는 로그인 자체를 실패시키지 않습니다.

## 7.5 운영 체크

- release 전 CI/배포 workflow 성공 여부 확인
- Backend migration이 필요한 release인지 확인
- Backend와 Frontend API 계약 동시 배포 필요 여부 확인
- Web 배포 실패 시 workflow의 rollback 로그 확인
- Firebase credential 및 운영 API 접근 상태 확인
