# annual_leave_frontend 인수인계 기술 문서

연차 관리 앱의 클라이언트(**Flutter, Android/iOS/Web 크로스플랫폼**) 인수인계용 기술 문서 모음입니다. 백엔드는 별도 저장소 [`annual-leave-backend`](../../annual-leave-backend)이며, REST API(JWT 인증)로 통신합니다.

각 문서는 **현재 코드 기준 사실**을 기술하며, 개선 아이디어는 "주의점 / 제안" 소절로 분리했습니다.

## 문서 목록

| 번호 | 문서 | 내용 |
|---|---|---|
| 01 | [시스템 아키텍처](01-system-architecture.md) | 전체 그림, 백엔드 연동, 플랫폼별 baseUrl |
| 02 | [개발 환경 / 빌드·실행](02-dev-environment.md) | Flutter 셋업, 실행/빌드 명령, 로컬 백엔드 연결 |
| 03 | [앱 아키텍처](03-app-architecture.md) | 디렉토리 구조, 라우팅, Provider 상태관리, 레이어링 |
| 04 | [화면 카탈로그](04-screens-catalog.md) | 11개 화면 상세(목적/의존성/관리자 전용 여부) |
| 05 | [데이터 모델 및 API 연동](05-data-models-api-integration.md) | models/, 엔드포인트 매핑표, 백엔드 교차 검증 결과 |
| 06 | [인증 / 보안](06-auth-security.md) | JWT 저장, 자동로그인, 401 미처리, 역할 기반 UI의 한계 |
| 07 | [배포 / 운영](07-deployment-operations.md) | 플랫폼별 빌드, Vercel 웹 배포 현황, CI 부재 |

## 빠른 요약

- **기술 스택**: Flutter(Dart) 3.5+, `provider`(상태관리), `dio`(HTTP), `flutter_secure_storage`(JWT 저장), `table_calendar`, `google_fonts`.
- **플랫폼**: Android / iOS / Web 동시 빌드 대상. Web은 Vercel에 정적 배포된 것으로 추정(저장소에 배포 설정 파일 없음).
- **서비스 레이어**: 별도 API 서비스 모듈 없이 `ApiClient`(dio 싱글턴) 하나만 존재, 엔드포인트 호출이 Provider·화면에 분산.
- **인증**: JWT를 `flutter_secure_storage`에 저장, 요청마다 자동 첨부. **401 자동 로그아웃 처리 없음**(06 문서 참조).
- **역할 분기**: 관리자 메뉴는 클라이언트에서 UI만 숨기며, 라우트 자체는 보호되지 않음(서버 인가에 의존).
- **테스트/CI**: 테스트 코드·CI 파이프라인 없음.

## ⚠️ 백엔드와 교차 검증 중 발견한 주요 이슈

- **`LeaveType` 코드 불일치**: 프론트엔드 enum은 `ALTERNATE`/`PARENTAL`을 전송하지만, 백엔드 `LeaveType` enum은 `ALTERNATIVE`/`PERENTAL`을 기대합니다. 이 두 휴가 유형은 **신청 시 400 오류로 실패할 수 있는 실제 버그**입니다 → [05 §5.4](05-data-models-api-integration.md#54-알려진-불일치-크로스-레포-검증-결과).
- **전체 신청 목록 조회 권한**: `/api/leave-requests/all`은 백엔드에서 ADMIN 권한을 요구하지 않아(인증만 필요), 프론트 UI도 이를 관리자 전용으로 제한하지 않습니다 — 일반 직원이 전직원의 휴가 신청 내역을 조회할 수 있습니다 → [05 §5.4](05-data-models-api-integration.md#54-알려진-불일치-크로스-레포-검증-결과).

이 두 항목은 실제 동작에 영향을 주는 발견 사항이므로 우선적으로 확인을 권장합니다.
