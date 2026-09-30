# 06. 인증 / 보안

## 6.1 JWT 저장과 요청 첨부

공통 HTTP 클라이언트는 `lib/core/network/api_client.dart`의 `ApiClient`입니다. Access JWT는 `flutter_secure_storage`의 `jwt_token` 키에 저장합니다.

`/api/auth/signin`, `/api/auth/signup`, 계정 찾기처럼 공개 인증 API에는 기존 JWT를 붙이지 않습니다. 그 외 인증 API 호출은 저장된 JWT가 있으면 `Authorization: Bearer <token>`을 자동으로 전송합니다.

## 6.2 로그인 원자성

`AuthSession.login()`은 다음 순서로 세션을 확정합니다.

1. `POST /api/auth/signin`
2. JWT 저장
3. `GET /api/employees/me`
4. 내 정보 조회까지 성공한 경우에만 `isLoggedIn=true`로 전환

3단계가 실패하면 저장된 JWT와 메모리 세션 상태를 함께 정리합니다. 따라서 signin만 성공하고 화면 세션이 반쯤 남는 상태를 허용하지 않습니다.

앱 시작 시 `tryAutoLogin()`도 저장된 JWT로 `/api/employees/me`를 호출해 실제 사용 가능 여부를 확인합니다.

## 6.3 401 세션 만료

`ApiClient`는 **Authorization 헤더가 실제로 붙었던 요청**이 401을 반환한 경우에만 세션 만료 처리기를 실행합니다.

- 저장된 JWT 삭제
- `AuthSession.expireSession()`으로 role/name/employeeInfo 초기화
- 전역 Navigator를 통해 `/login`으로 이동하고 기존 route stack 제거

반대로 로그인 비밀번호 오류 등 공개 `/api/auth/**` 요청의 401은 현재 세션 만료로 오인하지 않습니다.

현재 구조는 Access JWT 기반이며 Refresh Token Rotation은 아직 적용하지 않았습니다. 따라서 Access JWT가 만료되면 자동 refresh가 아니라 재로그인이 필요합니다.

## 6.4 현재 권한과 JWT role

Frontend의 메뉴 표시는 `/api/employees/me`가 반환한 현재 role을 사용합니다.

Backend는 JWT의 로그인 시점 role snapshot을 관리자 권한의 최종 근거로 사용하지 않습니다. `/api/admin/**`은 인증 여부를 통과한 뒤 각 관리자 controller가 `AuthService.checkAdmin()` 또는 `checkPersonnelAuthority()`로 현재 TeamManager/직급 상태를 재검증합니다.

따라서 로그인 중 PM 승격·해제가 발생해도 관리자 API의 실제 권한은 현재 조직 상태가 기준입니다.

## 6.5 로그아웃과 FCM

Drawer 로그아웃은 먼저 `FcmService.unregisterToken()`을 호출합니다. 등록된 FCM token이 있으면 `POST /api/auth/logout`으로 서버 topic/token 매핑을 정리한 뒤 클라이언트 token과 JWT를 삭제하고 로그인 화면으로 이동합니다.

서버 FCM 정리 실패는 로그아웃 자체를 막지 않도록 처리되어 있습니다.

## 6.6 UI와 서버 인가

관리자 전용 메뉴를 숨기는 것은 UX 제어일 뿐 보안 경계가 아닙니다. 실제 데이터 접근권한은 항상 Backend가 결정합니다.

휴가 상세의 신청 사유·연차 snapshot처럼 민감한 필드는 서버가 권한에 따라 null을 반환하고, Frontend는 값이 있을 때만 동적으로 렌더링합니다.
