# 06. 인증 / 보안

## 6.1 JWT 저장과 요청 첨부

공통 HTTP 클라이언트는 `lib/core/network/api_client.dart`의 `ApiClient`입니다. Access JWT는 `flutter_secure_storage`의 `jwt_token` 키에 저장합니다.

`/api/auth/signin`, `/api/auth/signup`, 계정 찾기처럼 공개 인증 API에는 기존 JWT를 붙이지 않습니다. `/api/auth/logout`과 그 외 인증 API에는 저장된 JWT가 있으면 `Authorization: Bearer <token>`을 자동 첨부합니다.

## 6.2 로그인 원자성과 현재 role

`AuthSession.login()`은 다음 순서로 세션을 확정합니다.

1. `POST /api/auth/signin`
2. JWT 저장
3. `GET /api/employees/me`
4. `/me`까지 성공한 경우에만 `isLoggedIn=true`

signin 성공 뒤 `/me`가 실패하면 저장 JWT와 메모리 세션을 모두 정리합니다.

signin 응답의 role은 로그인 순간의 snapshot일 수 있으므로 최종 세션 role/name은 **`/api/employees/me` 응답을 정본**으로 사용합니다. 앱 시작의 `tryAutoLogin()`도 같은 `/me` 검증을 거칩니다.

## 6.3 401 세션 만료

`ApiClient`는 실제로 Authorization 헤더가 붙은 요청이 401을 반환했을 때만 전역 세션 만료를 실행합니다.

1. 저장 JWT 삭제
2. `AuthSession.expireSession()`으로 role/name/employeeInfo 초기화
3. 전역 Navigator로 `/login` 이동 및 기존 route stack 제거
4. FCM local token/listener best-effort 정리

로그인 비밀번호 오류 같은 공개 auth 요청의 401은 기존 세션 만료로 취급하지 않습니다.

현재 구조는 Access JWT 기반이며 Refresh Token Rotation은 아직 적용하지 않았습니다. Access JWT 만료 시 자동 refresh 대신 재로그인이 필요합니다.

## 6.4 실제 관리자 권한

Frontend의 role과 관리자 메뉴는 UX 상태입니다. 실제 권한은 Backend가 결정합니다.

Backend 권한 경계:

```text
Spring Security
  └─ /api/admin/** 인증 확인
       └─ AdminAuthorizationInterceptor
            ├─ 기본: CurrentAuthorityService.requireAdmin()
            └─ @RequirePersonnelAuthority:
               CurrentAuthorityService.requirePersonnelAuthority()
```

따라서 JWT의 로그인 시점 role snapshot은 최종 인가 근거가 아닙니다. 휴가 승인/반려는 여기에 더해 해당 신청의 **현재 결재선**도 서비스에서 다시 검증합니다.

## 6.5 개인정보

휴가 상세의 신청 사유, 연차 snapshot, 반려 사유 같은 private 필드는 Backend가 조회자 기준으로 제어합니다.

- 본인: 열람 가능
- 현재 관리자: 관리자 정책에 따라 열람 가능
- 일반 직원의 타인 조회: private 필드 null

Frontend는 서버가 null로 생략한 행을 렌더링하지 않습니다.

## 6.6 로그아웃과 FCM

명시적 로그아웃은 `FcmService.unregisterToken()`으로 서버의 token/topic 매핑을 best-effort 정리한 뒤 클라이언트 token/JWT/세션을 제거합니다.

세션 만료(401) 때는 만료 JWT로 logout API를 다시 호출하지 않고 세션을 먼저 종료한 뒤 로컬 Firebase token과 listener를 정리합니다. FCM 정리 실패가 인증 상태 초기화를 막아서는 안 됩니다.
