# 03. 앱 아키텍처

## 3.1 현재 구조

Frontend는 feature-first MVVM 구조입니다.

```text
lib/
├── main.dart
├── app/
│   └── app.dart                 # MaterialApp, route, AuthSession 등록
├── core/
│   ├── config/                  # ApiConfig
│   ├── error/                   # Failure / Result
│   ├── network/                 # ApiClient(Dio)
│   ├── services/                # FcmService
│   ├── theme/
│   └── widgets/
└── features/
    ├── auth/
    ├── dashboard/
    ├── employee/
    ├── leave/
    └── admin/
        └── {models,repositories,view_models,views,...}
```

기능별 HTTP 호출은 `features/*/repositories/`에 모여 있고 화면 상태와 화면 로직은 ViewModel(`ChangeNotifier`)이 담당합니다. 화면은 ViewModel을 생성해 사용하며 직접 Dio 계약을 구성하지 않습니다.

## 3.2 상태와 호출 흐름

```text
View
  ↓
ViewModel(ChangeNotifier)
  ↓
Repository
  ↓
ApiClient(Dio singleton)
  ↓
Backend /api/**
```

- 앱 루트에 등록되는 전역 `ChangeNotifier`는 **`AuthSession` 하나**입니다.
- Dashboard/Leave/Admin 등의 상태는 화면 단위 ViewModel에서 관리합니다.
- `ApiClient`는 JWT 첨부, 서버 오류 message 보존, 인증된 401의 세션 만료 트리거를 담당합니다.
- `FcmService`는 앱 수명주기의 FCM token/listener를 담당합니다.
- 일부 순수 검증은 UseCase(`SubmitLeaveRequest`)로 분리되어 있습니다.
- React Query/SWR류의 서버 상태 캐시는 없으며 필요한 시점에 Repository를 통해 다시 조회합니다.

## 3.3 앱 루트와 라우팅

`lib/app/app.dart`가 `MaterialApp`, `rootNavigatorKey`, `routeObserver`, named route를 정의합니다. 최초 화면은 `SplashScreen`입니다.

| 라우트 | 화면 | 비고 |
|---|---|---|
| home | `SplashScreen` | 자동 로그인 후 login/dashboard 분기 |
| `/login` | `AUT001_M01` | 공개 |
| `/signup` | `AUT002_M01` | 공개 |
| `/forgot-password` | `AUT003_M01` | 공개 |
| `/dashboard` | `DSH001_M01` | 인증 |
| `/leave-request` | `LVE001_M01` | 인증 |
| `/all-leave-requests` | `LVE002_M02` | 인증 |
| `/pending-approval` | `LVE003_M01` | 관리자 UX 메뉴, 실제 인가는 Backend |
| `/admin-settings` | `ADM001_M01` | 관리자 UX 메뉴 |
| `/signup_manage_screen` | `ADM002_M01` | 관리자 UX 메뉴 |
| `/department-team-manage` | `ADM003_M01` | 인사권 필요 |
| `/search_employee_number_screen` | `ADM004_M01` | 관리자 UX 메뉴 |
| `/my-info` | `EMP001_M01` | 인증 |

`LVE002_M01` 내 신청 전용 화면 파일은 남아 있지만 named route에는 등록되어 있지 않습니다. 현재 내 신청 기능은 `LVE002_M02`의 "내 신청" 모드가 제공합니다.

## 3.4 인증 상태

`AuthSession`은 다음만 보관합니다.

- 로그인 여부
- 현재 role/name
- `Employee employeeInfo`

로그인 확정 시 `POST /api/auth/signin` 뒤 `GET /api/employees/me`까지 성공해야 합니다. 최종 role/name은 signin snapshot이 아니라 **`/me` 응답을 정본**으로 사용합니다.

UI의 `isAdmin`은 메뉴 표시용이며 보안 경계가 아닙니다. 실제 관리자/인사권/결재권은 Backend가 현재 조직 상태로 다시 검증합니다.

## 3.5 Repository 경계

대표 Repository는 다음과 같습니다.

- `AuthRepository`
- `DashboardRepository`
- `LeaveRepository`, `PublicHolidayRepository`
- `EmployeeRepository`
- `AdminEmployeeRepository`
- `SignupManageRepository`
- `CommonCodeRepository`
- `DepartmentTeamRepository`

Endpoint 변경 시 View나 Provider를 찾는 것이 아니라 해당 Repository와 모델, ViewModel 테스트를 우선 확인합니다.

## 3.6 비동기/UI 안정성

- 검색/목록 화면은 request sequence를 사용해 늦게 도착한 이전 응답이 최신 검색 결과를 덮지 않게 합니다.
- ViewModel은 dispose 이후 `notifyListeners()`를 피하도록 상태를 관리합니다.
- 휴가 신청 기간은 Backend `/api/leave-requests/my/period` 응답을 정본으로 사용합니다.
- 인증된 요청의 401은 `AuthSession`을 먼저 만료시키고 로그인 화면으로 복귀한 뒤 FCM 로컬 상태를 best-effort로 정리합니다.

## 3.7 유지보수 원칙

- HTTP 계약은 Repository에 둡니다.
- 화면별 상태/동작은 ViewModel에 둡니다.
- 로그인/현재 사용자 상태만 `AuthSession`에 둡니다.
- UI role/route를 보안 경계로 사용하지 않습니다.
- Backend DTO/권한/상태 계약이 바뀌면 Repository 테스트와 관련 문서를 같은 변경에서 갱신합니다.
