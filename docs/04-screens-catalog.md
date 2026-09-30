# 04. 화면 카탈로그

현재 라우트에 등록된 12개 화면과, 라우트에서 제외된 내 신청 전용 화면 1개를 정리합니다. 실제 서버 호출은 각 화면의 ViewModel/Repository를 거치며, 공통 HTTP 처리는 `lib/core/network/api_client.dart`의 `ApiClient`가 담당합니다.

## 4.1 LoginScreen (`/login`)
파일: `lib/features/auth/views/AUT001_M01.dart`

- 사번/비밀번호 입력 → `AuthSession.login()` → `POST /api/auth/signin`, 이어서 `GET /api/employees/me`로 현재 사용자 정보를 확정합니다.
- 로그인 성공 뒤 대시보드로 이동합니다.
- 인증된 API가 401을 반환하면 저장 JWT와 `AuthSession`을 만료시키고 로그인 화면으로 복귀합니다.

## 4.2 SignupScreen (`/signup`)
파일: `lib/features/auth/views/AUT002_M01.dart`

- 관리자가 미리 등록한 사번으로 최초 비밀번호를 설정합니다.
- Backend `POST /api/auth/signup`을 사용합니다.

## 4.3 FindAccountScreen (`/forgot-password`)
파일: `lib/features/auth/views/AUT003_M01.dart`

- 아이디 찾기: `POST /api/auth/find-id`
- 비밀번호 초기화/찾기: `POST /api/auth/forgot-password`

## 4.4 DashboardScreen (`/dashboard`)
파일: `lib/features/dashboard/views/DSH001_M01.dart`

- `DashboardViewModel`이 `GET /api/dashboard`를 조회합니다.
- 내 연차/신청 현황을 표시하고, 서버가 관리자용 집계 데이터를 내려준 경우 관리자 현황도 표시합니다.
- 관리자 세션에서는 FCM token/topic 동기화를 수행합니다.

## 4.5 LeaveRequestScreen (`/leave-request`)
파일: `lib/features/leave/views/LVE001_M01.dart`

- `LeaveRequestViewModel` + `LeaveRepository` 구조입니다.
- `GET /api/leave-requests/my/period`의 `startDate/endDate`를 현재 연차기간의 정본으로 사용하므로 Frontend가 회계연도/입사일 정책을 별도로 추론하지 않습니다.
- 주말·공휴일·재직기간 밖 날짜는 선택할 수 없습니다.
- 반차는 단일 날짜 0.5일이며, 그 외 휴가는 선택 범위의 근무일수를 사용합니다.
- 제출은 `SubmitLeaveRequest`를 통해 `POST /api/leave-requests`로 전송합니다.

## 4.6 AllLeaveRequestsScreen (`/all-leave-requests`)
파일: `lib/features/leave/views/LVE002_M02.dart`

- 내 신청 조회는 `GET /api/leave-requests/my`, 전체 조회는 `GET /api/leave-requests/all`을 사용합니다.
- 목록 요청은 sequence 번호로 최신 응답만 반영해 검색/필터 변경 시 응답 역전을 방지합니다.
- 서버가 비공개 필드를 `null`로 내려주면 Frontend는 해당 내용을 표시하지 않습니다.
- 본인 신청 중 `PENDING`은 취소 가능하며, `APPROVED`도 시작일이 오늘보다 미래인 경우 취소 UI를 제공합니다.

## 4.7 PendingApprovalScreen (`/pending-approval`)
파일: `lib/features/leave/views/LVE003_M01.dart`

- 대기 목록: `GET /api/admin/leave-requests/pending`
- 승인: `POST /api/admin/leave-requests/{id}/approve`
- 반려: `POST /api/admin/leave-requests/{id}/reject`
- 실제 인가는 Backend의 현재 관리자/결재선 검증이 최종 기준입니다.
- 반려 사유 입력은 Backend 계약과 동일하게 200자로 제한합니다.

## 4.8 AdminSettingsScreen (`/admin-settings`)
파일: `lib/features/admin/views/ADM001_M01.dart`

- 직원을 선택해 현재 관리 팀을 조회하고 추가/삭제합니다.
- 저장은 `PUT /api/admin/employees/{employeeNumber}/managed-teams`의 expected/desired 상태 계약을 사용합니다.
- 저장 충돌이나 결과가 불명확한 경우 서버 상태를 다시 읽어 화면을 재조정합니다.

## 4.9 SignupManageScreen (`/signup_manage_screen`)
파일: `lib/features/admin/views/ADM002_M01.dart`

- `GET /api/admin/auth/common`에서 현재 관리자가 사용할 수 있는 부서·팀·직급 데이터를 받습니다.
- `POST /api/admin/auth/register`로 사원을 등록합니다.
- 사원 등록 화면에서 신규 팀을 즉석 생성하지 않습니다. 팀이 필요하면 먼저 부서/팀 관리 화면에서 생성해야 합니다.
- 이메일 형식 등 기본 입력 검증을 Frontend에서도 수행하며 Backend DTO 검증이 최종 방어선입니다.

## 4.10 DepartmentTeamManageScreen (`/department-team-manage`)
파일: `lib/features/admin/views/ADM003_M01.dart`

- 부서와 팀의 조회/생성/수정/삭제를 담당합니다.
- `/api/admin/departments`, `/api/admin/teams` 계약을 사용합니다.
- 신규 팀 생성 시 담당자 1명은 필수입니다. 담당자 없는 팀 생성은 Frontend와 Backend에서 모두 거부합니다.
- 상위 팀을 생략하면 Backend가 대표이사 팀을 기본 상위 팀으로 사용합니다.
- 이 영역은 Backend의 현재 인사권 검증 대상입니다.

## 4.11 SearchEmployeeNumberScreen (`/search_employee_number_screen`)
파일: `lib/features/admin/views/ADM004_M01.dart`

- `GET /api/admin/employees/all`을 이용해 사번/성명 조건으로 직원을 조회합니다.
- 직원 상세 편집은 expected 상태를 함께 보내는 compare-and-set 계약을 사용합니다.
- 관리자는 직원의 연차 정보 등 관리자용 응답 필드를 조회할 수 있습니다.

## 4.12 MyInfoScreen (`/my-info`)
파일: `lib/features/employee/views/EMP001_M01.dart`

- `AuthSession.employeeInfo`와 대시보드 데이터를 이용해 본인 정보를 표시합니다.
- 이메일 변경: `PATCH /api/employees/me/email`
- 비밀번호 변경: `PATCH /api/employees/me/password`

## 4.13 (라우트 제외) MyLeaveRequestsScreen
파일: `lib/features/leave/views/LVE002_M01.dart`

현재 `app.dart`의 named route에는 등록되어 있지 않습니다. 내 신청 기능은 `AllLeaveRequestsScreen`의 내 신청 모드로 제공됩니다.

## 4.14 공통 UI/권한 원칙

- UI에서 관리자 메뉴를 숨기는 것은 편의 기능이며 실제 인가는 Backend가 담당합니다.
- 관리자 role 표시는 `GET /api/employees/me`의 현재 조직 상태 기반 응답을 사용합니다.
- 휴가 사유·연차 snapshot 같은 민감 필드는 서버가 권한에 따라 값을 생략하며, Frontend는 값이 있을 때만 렌더링합니다.
- API 오류는 `ApiClient`가 서버의 문자열 `message`를 보존하고, 화면별 ViewModel이 사용자용 메시지를 결정합니다.
