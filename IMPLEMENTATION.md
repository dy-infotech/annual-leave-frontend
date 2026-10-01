# IMPLEMENTATION

이 문서는 `annual_leave_frontend`의 구현 불변조건과 예외 규칙을 정리합니다.
프로젝트 개요, 실행 방법, 화면 구성은 `README.md`를 기준으로 하고, 여기서는 코드를 수정할 때 유지해야 하는 동작을 설명합니다.


## 1. 기본 구조

프론트엔드는 다음 책임 분리를 유지합니다.

```text
View
  ↓ 사용자 입력 / 렌더링
ViewModel
  ↓ 화면 상태 / 비동기 흐름
Repository
  ↓ API 계약 / JSON 변환
ApiClient
  ↓ 인증 / 공통 HTTP 처리
Backend
```

- 앱 전체에서 공유하는 핵심 상태는 `AuthSession`입니다.
- 화면별 목록/입력/로딩 상태는 해당 ViewModel이 소유합니다.
- View가 직접 Dio를 호출하지 않습니다.
- 권한, 조직 범위, 연차기간, 휴가 일수, 전체 건수는 backend가 최종 정본입니다.


## 2. ApiClient / 인증 수명주기

`ApiClient`는 앱 전체가 공유하는 Dio 싱글턴이자 Access Token 수명주기 관리자입니다.

### Access / Refresh 분리

- Access JWT: `flutter_secure_storage`
- Refresh Token: HttpOnly Cookie
- SSO session marker: secure storage
- Web 요청: `BrowserHttpClientAdapter(withCredentials: true)`

`/api/auth/**` 요청에는 Access JWT를 자동 첨부하지 않으며 401 자동 refresh 재시도도 적용하지 않습니다.

### 선제 Refresh / 401 재시도

- Access JWT가 만료되기 45초 이내면 요청 전에 refresh를 시도합니다.
- 일반 API 요청이 401이면 refresh 후 **최대 1회** 같은 요청을 재시도합니다.
- 인증 요청 자체는 이 재시도 대상이 아닙니다.
- 401/403으로 Refresh Session 무효가 확정된 경우에만 로컬 세션을 만료시킵니다.
- 네트워크 오류와 5xx는 일시 장애일 수 있으므로 자동 로그아웃 사유로 취급하지 않습니다.

### 세션 세대 `_authGeneration`

로그인, 로그아웃, 세션 만료 등 인증 상태가 바뀌면 세대 번호가 변경됩니다.

각 인증 요청은 전송 당시 세대를 기억하고 응답 시 현재 세대와 비교합니다.

이 규칙의 목적:

- 로그아웃 직후 늦게 도착한 이전 계정 응답 무시
- 계정 전환 후 이전 계정의 401/refresh 결과 무시
- refresh 도중 로그아웃했는데 새 token이 다시 저장되는 문제 방지

`ApiClient.sessionGeneration`과 `AuthSession` 내부 generation은 별도 개념이므로 서로 직접 비교하지 않습니다.

### Token mutation 직렬화

`_tokenMutation` Future chain은 secure storage의 token/session marker 변경을 직렬화합니다.

인증 헤더를 붙이는 요청은 mutation이 끝난 다음 token을 읽어야 합니다.
이 순서를 제거하면 로그인/로그아웃/refresh와 일반 API 요청이 서로 다른 token snapshot을 볼 수 있습니다.

### Refresh single-flight

`_refreshInFlight`는 한 isolate에서 여러 요청이 동시에 refresh를 호출해도 실제 refresh 요청을 하나로 합칩니다.

새 refresh 코드를 추가할 때 이 single-flight를 우회하지 않습니다.


## 3. 브라우저 탭 간 SSO

HttpOnly Refresh Cookie는 같은 origin의 여러 탭이 공유하지만 Dart 메모리는 공유하지 않습니다.

Web에서는 `shared_sso_lock_web.dart`가 localStorage의 `dy_sso_cookie_mutation_lock`을 사용해 Refresh Cookie를 변경하는 동작을 탭 간 직렬화합니다.

### 409 처리

refresh 중 409가 발생하면 무조건 로그아웃하거나 무한 재시도하지 않습니다.

1. `/api/auth/session-marker`로 현재 cookie session을 확인합니다.
2. 현재 Access 세션 marker와 다르면 이 탭의 로컬 세션만 만료합니다.
3. marker가 같으면 잠시 후 secure storage를 다시 읽어 다른 탭이 저장한 새 Access Token이 있는지 확인합니다.
4. 없다면 refresh를 한 번만 더 시도합니다.

다른 사용자의 Access Token으로 조용히 전환되는 것도 허용하지 않습니다. refresh 결과의 employeeId가 기존 token subject와 다르면 현재 세션을 만료합니다.


## 4. 명시적 로그아웃 / 자동 로그인

Splash 화면에서 자동 로그인을 시도합니다.

- 자동 로그인 설정이 꺼져 있으면 이전 로컬 인증 상태를 정리합니다.
- 명시적 로그아웃 상태는 단순히 Refresh Cookie가 남아 있다는 이유만으로 즉시 자동 복원하면 안 됩니다.
- 다른 시스템/탭에서 이후 생성된 새 SSO session은 session marker를 이용해 이전 명시 로그아웃 세션과 구분합니다.

세션 만료 callback은 `ApiClient.sessionGeneration`이 아직 동일할 때만 로그인 화면으로 이동해야 합니다.
늦게 도착한 과거 세션의 만료 callback이 새 로그인을 끊어서는 안 됩니다.


## 5. AuthSession / 권한

`AuthSession`은 현재 사용자 정보와 UI용 role 상태를 관리합니다.

- 로그인 후 Access Token 저장 → `/api/employees/me` 조회 순서로 현재 사용자 정보를 맞춥니다.
- 대시보드 진입 시에도 사용자 정보를 다시 조회해 메뉴/권한 표시를 최신화합니다.
- `isAdmin`, Drawer의 관리자 메뉴 노출은 **UX용 정보**입니다.
- 실제 API 접근 가능 여부는 항상 backend가 결정합니다.

Named route 자체에는 별도 client-side 인증/인가 guard가 없습니다.
Splash 자동 로그인과 서버 401/403이 실제 세션 상태를 결정합니다.

프론트의 메뉴 숨김을 보안 통제로 간주하거나 서버 권한 검증 대신 사용하면 안 됩니다.


## 6. ViewModel 비동기 경합

대부분의 ViewModel은 다음 패턴을 사용합니다.

- `_requestSeq`: 최신 요청 번호
- `_disposed`: ViewModel 폐기 여부
- 요청 시작 시 현재 seq 저장
- 응답 후 `seq == _requestSeq`인지 확인
- dispose 시 seq 증가

이 패턴은 검색조건을 빠르게 바꾸거나 화면을 떠난 뒤 **이전 요청이 늦게 완료되어 최신 상태를 덮는 문제**를 막습니다.

새 fetch/search 로직에서도 이 검증을 생략하지 않습니다.

추가 조회(`loadMore`)는 최소한 다음 조건에서 중복 실행하지 않습니다.

```text
disposed
isLoading
isLoadingMore
hasMore == false
```


## 7. 연차 신청

`LVE001_M01`은 UI에서 사전 검증을 수행하지만 최종 판정은 backend입니다.

### 연차기간

- `/api/leave-requests/my/period` 응답의 시작일/종료일을 우선 사용합니다.
- 조회 실패 시에만 현재 연도 1/1~12/31을 fallback으로 사용합니다.
- 날짜 선택 가능 여부는 연차기간, 입사일, 퇴사일, 주말/공휴일 등을 반영합니다.

### 클라이언트 사전 검증

클라이언트는 UX를 위해:

- 기존 신청과 기간 중복
- 남은 연차보다 큰 신청
- 반차/기간 입력
- 사유 필수 여부

등을 미리 검사할 수 있습니다.

이 결과는 서버 검증을 대체하지 않습니다.

### 신청 멱등성

submit 시 payload signature에 대응하는 `Idempotency-Key`를 생성합니다.

- 동일 payload를 같은 submit 흐름에서 재시도할 때는 같은 key를 유지합니다.
- payload가 바뀌면 새 key를 생성합니다.
- 성공 후에는 key/signature를 초기화합니다.

네트워크 재시도 때문에 같은 휴가가 중복 생성되지 않도록 이 규칙을 유지합니다.


## 8. 신청 목록 정책

`/all-leave-requests`는 **모든 사용자에게 전체 목록을 기본으로 제공**합니다.

- 기본: 올해 전체 신청
- 선택 필터: `내 신청`
- 관리자 여부로 전체 목록 자체를 숨기지 않습니다.
- `LVE002_M01` 내 신청 전용 화면은 route에 등록하지 않고 현재 통합 목록 화면의 필터가 그 역할을 합니다.

현재 연도 범위 적용은 의도된 화면 정책입니다.


## 9. 페이지네이션 / 무한스크롤

Repository의 휴가 목록 응답은:

```dart
PageResult<T>(
  items,
  totalCount,
  hasMore,
)
```

를 사용합니다.

### 절대 바꾸면 안 되는 계약

- 전체 건수 표시: `page.totalCount`
- 다음 페이지 여부: `page.hasMore`
- 현재 적재량 `items.length`를 전체 건수로 사용하지 않음
- `items.length == pageSize`로 hasMore를 추측하지 않음

### Cursor

일반 신청 목록:

```text
cursorRequestedAt + cursorRequestId
```

승인/반려/승인대기:

```text
cursorCreatedAt + cursorRequestId
```

두 cursor 값은 쌍으로 전달합니다.

ViewModel은 마지막 row의 cursor를 다음 요청에 사용하고, 이미 받은 `requestId`는 중복 추가하지 않습니다.

### 200건 제한 없음

페이지 크기는 기본 50건이지만 4페이지에서 중단하는 로직은 없습니다.

`hasMore=true`인 동안 200건을 넘어 계속 조회해야 합니다.

Repository의 전체 수집 helper에 있는 `_maxCursorBatches = 1000`은 cursor가 전진하지 않는 비정상 상태의 무한루프 방어선이지 정상 목록의 200건 제한이 아닙니다.


## 10. 관리자 목록

사원 선택/관리 화면 일부는 cursor 대신 `page/size` OFFSET pagination을 사용합니다.

- 화면 무한스크롤은 ViewModel의 현재 page를 증가시켜 다음 page를 요청합니다.
- 검색/팀 필터가 바뀌면 page와 기존 목록을 초기화합니다.
- 화면별 pagination 방식이 다르므로 휴가 cursor 로직을 관리자 사원 목록에 기계적으로 복사하지 않습니다.


## 11. FCM lifecycle

`FcmService`는 Firebase token과 서버 binding을 관리합니다.

- FCM 동기화는 현재 관리자 인증 상태에서 `/api/admin/auth/sync-fcm-token`을 사용합니다.
- 등록한 FCM token은 SharedPreferences에 저장합니다.
- Web SSO에서는 현재 `authSessionMarker`도 서버에 전달해 token binding을 세션과 연결합니다.
- 동일 lifecycle 작업은 직렬화해 register/logout/expiry cleanup 경합을 줄입니다.
- 명시적 로그아웃 전에 현재 FCM context를 먼저 캡처한 뒤 서버 로그아웃을 실행합니다.
- 세션 만료 시에는 만료된 JWT로 logout API를 다시 호출하지 않고 로컬 Firebase 상태를 best-effort로 정리합니다.
- 정리 도중 새 로그인이 시작됐다면 새 세션의 token을 삭제하지 않아야 합니다.

FCM 정리 실패가 인증 상태 확정을 막아서는 안 됩니다.


## 12. API 오류 / 로그

`ApiClient`는 backend 오류 응답의 message를 가능한 경우 `DioException.message`로 정규화합니다.

Debug 빌드에서만 API 요청을 로그로 남깁니다.

- Authorization header는 출력하지 않습니다.
- body의 민감정보는 마스킹합니다.
- release에서 디버그 요청 로그를 활성화하지 않습니다.


## 13. API 주소

`ApiConfig` 우선순위:

```text
API_BASE_URL dart-define
> debug 개발 주소
> release/profile 운영 주소
```

운영 기본 주소는 `https://app.dyinfotech.com`입니다.

실기기 개발은 Android emulator용 `10.0.2.2`를 그대로 사용하지 말고 `API_BASE_URL`로 개발 PC의 접근 가능한 주소를 지정합니다.


## 14. 테스트 / 배포

기본 검증:

```bash
flutter analyze --no-fatal-infos
flutter test
flutter build web --release
```

CI도 이 순서로 정적 분석, 테스트, Web release build를 수행합니다.

`release` push는 Frontend CD를 자동 실행하며 `build/web` 결과를 운영 Web 경로에 배포합니다.


## 15. 변경 시 지켜야 할 기준

- backend를 권한/조직/연차기간/전체 건수의 신뢰의 근원으로 유지합니다.
- 관리자 UI 노출 여부를 보안 경계로 사용하지 않습니다.
- 전체 신청 기본 조회에 다시 `isAdmin` 제한을 넣지 않습니다.
- `totalCount`를 현재 로드된 item 수로 대체하지 않습니다.
- `hasMore`를 page 길이로 다시 추정하지 않습니다.
- 200건 hard cap을 추가하지 않습니다.
- 복합 cursor의 시간값과 requestId를 분리하지 않습니다.
- ViewModel의 stale response 방지용 `_requestSeq/_disposed` 검사를 제거하지 않습니다.
- Access Token refresh의 `_authGeneration`, `_tokenMutation`, `_refreshInFlight` 역할을 합치거나 우회하지 않습니다.
- 브라우저 Refresh Cookie mutation의 shared SSO lock을 우회하지 않습니다.
- 5xx/네트워크 오류를 세션 만료로 처리하지 않습니다.
- 휴가 신청 멱등성 key를 매 재시도마다 새로 만들지 않습니다.
- FCM cleanup보다 로그인/로그아웃 인증 상태 확정을 뒤로 미루지 않습니다.
