# 04. 화면 카탈로그

11개 화면(+ 미사용 1개)의 목적, 의존 Provider/API, 관리자 전용 여부를 정리합니다. 공통 UI 패턴(폼 검증, 확인 다이얼로그, SnackBar)은 [§4.9](#49-공통-ui-패턴)에서 한 번에 설명합니다.

## 4.1 LoginScreen (`/login`)
파일: `lib/screens/login_screen.dart`

- 사번/비밀번호 입력 → `AuthProvider.login()` → 성공 시 `PublicHolidayProvider.fetchPublicHoliday()` 선행 로드 후 `/dashboard`로 이동.
- "사용 등록"(`/signup`), "아이디/비밀번호 찾기"(`/forgot-password`) 버튼 제공.
- ⚠️ 에러 메시지에 `e.toString()`을 그대로 노출하는 **디버그용 임시 코드**가 남아 있습니다("임시로 실제 에러 내용 확인" 주석, 55행) — 운영에서는 내부 예외 정보가 사용자에게 노출될 수 있습니다.

## 4.2 SignupScreen (`/signup`)
파일: `lib/screens/signup_screen.dart`

- 관리자가 미리 등록해둔 사번으로 최초 비밀번호를 설정하는 화면(백엔드 `POST /api/auth/signup`).
- 비밀번호/확인 일치 검증(클라이언트).
- ⚠️ 에러 메시지 조합에 `e.toString() + '등록되지 않은 사번이거나...11'`처럼 디버그 흔적(`11` 등)이 남아있는 코드가 있습니다(49~51행) — 정리 필요.

## 4.3 FindAccountScreen (`/forgot-password`)
파일: `lib/screens/forgotPasswordScreen.dart`

- 탭 2개(아이디 찾기 / 비밀번호 찾기)로 구성된 `TabController` 화면.
- **아이디 찾기**: 성함+이메일 → `AuthProvider.findId()` → 백엔드 `POST /api/auth/find-id`. 성공 시 사번을 화면에 표시.
- **비밀번호 찾기**: 사번+이메일 → `AuthProvider.sendPasswordResetEmail()` → 백엔드 `POST /api/auth/forgot-password`. 성공 시 SnackBar 후 이전 화면으로.
- `print()`로 에러를 콘솔에 출력하는 디버그 코드가 남아있음(82, 118행).

## 4.4 DashboardScreen (`/dashboard`)
파일: `lib/screens/dashboard_screen.dart`

- 진입 시 `DashboardProvider.fetchDashboard()`(`GET /api/dashboard`) 호출. `RouteAware`로 다른 화면에서 돌아올 때 자동 재조회([03 §3.5](03-app-architecture.md#35-화면-재진입-시-자동-새로고침)).
- 표시 섹션: "내 휴가 정보"(배정/사용/잔여), "내 휴가 신청 현황"(대기/승인/반려 카운트, 탭하면 `AllLeaveRequestsScreen(status: ..., filter: 'my')`로 이동), "전직원 휴가 신청 현황"(`allEmployeeRequestSummary`가 null이 아닐 때만 — 관리자 뱃지 표시, 탭하면 `filter: 'all'`로 이동).
- `RefreshIndicator`로 pull-to-refresh 지원.

## 4.5 LeaveRequestScreen (`/leave-request`)
파일: `lib/screens/leave_request_screen.dart`

- `table_calendar` 기반 날짜 범위 선택. 휴가 유형 드롭다운(`LeaveType` enum), 선택에 따라:
  - 반차(AM_HALF/PM_HALF): 단일 날짜, 사용일수 자동 0.5 고정.
  - 그 외: 시작~종료일 선택 시 주말/공휴일 제외하고 사용일수 자동 계산(`_calculateUsableDays`, `PublicHolidayProvider.isHoliday` 사용).
- 연차/반차를 제외한 유형(대체·출산·가족돌봄·기타) 선택 시에만 사유 입력란 노출.
- 제출 전 **클라이언트 측 중복 신청 검사**(`LeaveRequestListProvider.hasOverlap`) — 겹치면 확인 다이얼로그로 안내 후 제출 중단.
- 제출: `POST /api/leave-requests`(`ApiClient` 직접 호출, Provider 경유 안 함).
- 캘린더에 기존 신청(대기/승인) 날짜를 별표(⭐)로 표시(`LeaveRequestListProvider.isRequestedDate`).
- 신청자/결재자 카드에 `AuthProvider.employeeInfo`의 `approverName`/`approverPosition` 등을 표시.

## 4.6 AllLeaveRequestsScreen (`/all-leave-requests`)
파일: `lib/screens/all_leave_requests_screen.dart`

- 생성자 파라미터 `status`/`filter`(대시보드에서 `MaterialPageRoute`로 전달, 라우트 테이블 경유 시엔 없음)로 초기 필터 지정.
- 상태 드롭다운(전체/대기/승인/반려/취소), **"전체"/"내 신청" 라디오 버튼**, 기간 선택(`showDateRangePicker`).
- "내 신청" 선택 시 `GET /api/leave-requests/my`, "전체" 선택 시 `GET /api/leave-requests/all` 호출.
- ⚠️ **"전체"/"내 신청" 토글이 관리자 여부와 무관하게 모든 로그인 사용자에게 노출**됩니다(`auth.isAdmin` 체크 없음) — [05 §5.4](05-data-models-api-integration.md#54-알려진-불일치-크로스-레포-검증-결과) 참조.
- 본인이 올린 `PENDING` 상태 신청만 취소 가능(`_isCancelable`) → `DELETE /api/leave-requests/{id}`, 확인 다이얼로그 경유.
- 기본 조회 기간은 당해 1/1~오늘로 자동 설정됩니다(`_today` 기준).

## 4.7 PendingApprovalScreen (`/pending-approval`, 관리자 전용 메뉴)
파일: `lib/screens/pending_approval_screen.dart`

- `GET /api/admin/leave-requests/pending`으로 대기 목록 로드.
- 각 항목에 승인/반려 버튼. 승인은 확인 다이얼로그 후 `POST /api/admin/leave-requests/{id}/approve`. 반려는 사유 입력(선택) 다이얼로그 후 `POST /api/admin/leave-requests/{id}/reject`.
- 처리 중인 요청 ID를 `Set<int> _processingIds`로 추적해 버튼에 로딩 스피너 및 중복 클릭 방지.
- `RefreshIndicator` pull-to-refresh 지원.
- **화면 자체에 관리자 권한 검사 코드 없음** — 드로어에서만 숨겨질 뿐, URL(라우트)로 직접 진입하면 화면은 렌더링되고 API 호출만 백엔드 인가(`hasRole ADMIN`)에 의해 403으로 막힙니다.

## 4.8 SignupManageScreen (`/signup_manage_screen`, 관리자 전용 메뉴)
파일: `lib/screens/signup_manage_screen.dart`

- 진입 시 `GET /api/admin/auth/common`으로 부서/팀/직급 목록 로드(백엔드 `RegisterCommonDto`).
- 신규 사원 등록 폼: 이름/부서/팀/직급/역할(`RoleType`: 관리자·멤버)/이메일/입사일(날짜 선택기).
- 로그인한 관리자가 "대표이사" 직급이면 팀 드롭다운에 "기타"(신규 팀 생성용) 옵션을 동적으로 추가.
- 제출: `AuthProvider.adminAuthRegister()` → `POST /api/admin/auth/register`. 성공 시 `DashboardScreen`으로 강제 이동(`Navigator.push`, 스택에 쌓임 — `pushReplacement` 아님).
- 필드별 개별 에러 메시지(`_employeeNameError`, `_departmentError` 등)를 사용하는 검증 패턴.

## 4.9 SearchEmployeeNumberScreen (`/search_employee_number_screen`, 관리자 전용 메뉴)
파일: `lib/screens/search_employee_number_screen.dart`

- 사번/성명 검색어(`searchParam`)로 `GET /api/admin/employees/all` 조회.
- 결과 목록에 이름/직급/사번/이메일과 `RegisteStatusBadge`(가입 여부: `Employee.isRegisted`)를 표시.

## 4.10 MyInfoScreen (`/my-info`)
파일: `lib/screens/my_info_screen.dart`

- **기본 정보(읽기 전용)**: 사번/이름/직급/부서/입사일 + `DashboardProvider`의 연차정보(잔여/총) 표시. `AuthProvider.employeeInfo`와 `DashboardProvider.data` 두 Provider를 함께 구독.
- **이메일 변경**: 인라인 편집(연필 아이콘 토글) → `PATCH /api/employees/me/modify-email` → 성공 시 `AuthProvider.updateEmail()`로 로컬 상태 즉시 갱신(재조회 없이 optimistic update).
- **비밀번호 변경**: 현재/새/새 확인 3개 필드, 클라이언트에서 일치·현재비번과 동일 여부 검증 → `PATCH /api/employees/me/password`.

## 4.11 (미사용) MyLeaveRequestsScreen
파일: `lib/screens/my_leave_requests_screen.dart`

`main.dart`에서 import·라우트 등록이 주석 처리되어 **앱에서 도달 불가능**합니다. `AllLeaveRequestsScreen`(필터 "내 신청")으로 기능이 흡수된 것으로 보입니다. 문서화·유지보수 대상에서 제외하고, 삭제 여부를 결정하는 것을 권장합니다.

## 4.9 공통 UI 패턴

- **폼 검증**: 라이브러리 없이 `TextEditingController` + `setState`로 직접 구현. 제출 핸들러 상단에서 `isEmpty` 등 단순 검증 후 `String? _errorMessage`에 담아 표시.
- **로딩 상태**: 화면마다 `bool _isLoading`/`_isSubmitting`을 두고 버튼 비활성화 + 인라인 `CircularProgressIndicator` 반복 구현(공통 컴포넌트로 추출되어 있지 않음).
- **확인 다이얼로그**: 승인/반려/취소 등 파괴적 액션 전 `showDialog<bool>` 사용(연차 신청의 중복 경고 포함).
- **성공 피드백**: `ScaffoldMessenger.of(context).showSnackBar(...)`.
- **에러 표시**: 화면 하단에 `Text(errorMessage, style: TextStyle(color: AppColors.coral))` 인라인 표시가 대부분이며, `ApiClient`가 가공한 백엔드 메시지(`ErrorResponse.message`)를 그대로 쓰기보다 **화면별 고정 한글 문구로 대체하는 경우가 많습니다**(예: "신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.").
