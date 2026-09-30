# annual_leave_frontend 인수인계 기술 문서

연차 관리 앱의 Flutter 클라이언트 문서입니다. 백엔드는 별도 저장소 `annual-leave-backend`이며 JWT 기반 REST API로 통신합니다.

## 문서 목록

| 번호 | 문서 | 내용 |
|---|---|---|
| 01 | [시스템 아키텍처](01-system-architecture.md) | 전체 구조와 백엔드 연동 |
| 02 | [개발 환경 / 빌드·실행](02-dev-environment.md) | Flutter 셋업과 환경별 실행 |
| 03 | [앱 아키텍처](03-app-architecture.md) | feature 기반 구조, Provider, Repository |
| 04 | [화면 카탈로그](04-screens-catalog.md) | 주요 화면과 역할 |
| 05 | [데이터 모델 및 API 연동](05-data-models-api-integration.md) | DTO 모델과 endpoint 계약 |
| 06 | [인증 / 보안](06-auth-security.md) | JWT 저장, 자동 로그인, 401 만료 처리 |
| 07 | [배포 / 운영](07-deployment-operations.md) | GitHub Actions CI/CD와 Web 배포 |
| 참고 | [부서/팀 API 명세](api-spec-department-team.md) | develop_v2.0 조직 CRUD 계약 |
| 참고 | [화면 코드](screen-codes.md) | 화면 코드 체계 |
| 이력 | [MVVM 마이그레이션 기록](mvvm-migration-plan.md) | 완료된 구조 전환의 역사/의사결정 기록 |

## 현재 구조 요약

- **기술 스택**: Flutter, Provider, Dio, flutter_secure_storage, Firebase Messaging.
- **코드 구조**: `lib/features/<feature>/{models,repositories,view_models,views}` 중심으로 분리되어 있습니다.
- **인증**: Access JWT는 `flutter_secure_storage`의 `jwt_token`에 저장하고 `ApiClient`가 인증 API를 제외한 요청에 자동 첨부합니다.
- **세션 만료**: 인증된 API가 401을 반환하면 저장 JWT를 삭제하고 `AuthSession`을 만료시킨 뒤 로그인 화면으로 이동합니다. 로그인 실패처럼 공개 인증 API가 반환한 401은 기존 세션 만료로 취급하지 않습니다.
- **관리자 표시**: UI의 관리자 메뉴는 `/api/employees/me`에서 받은 현재 role을 기준으로 표시합니다. 실제 인가는 백엔드의 현재 조직/직급 검증이 최종 기준입니다.
- **휴가 코드**: Frontend/Backend 모두 `ALTERNATIVE`, `PARENTAL` 등 동일한 코드 계약을 사용합니다.
- **상세 개인정보**: 휴가 상세의 신청 사유·연차 snapshot은 서버가 권한에 따라 null로 내려주며, Frontend는 받은 값이 있을 때만 표시합니다.
- **검증**: `.github/workflows/ci.yml`에서 `flutter analyze --no-fatal-infos`, 전체 테스트, Web release build를 수행합니다.
- **배포**: `release` 브랜치의 `deploy.yml`이 Web build 후 서버 staging 디렉터리에 업로드하고, 검증 뒤 현재 디렉터리와 교체하며 실패 시 이전 버전으로 복원합니다.

문서보다 코드와 API 응답을 최종 정본으로 보며, endpoint나 DTO를 변경할 때 관련 repository 테스트와 이 문서도 함께 갱신합니다.
