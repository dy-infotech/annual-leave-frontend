# 05. 데이터 모델 및 API 연동

## 5.1 구조

현재 Frontend는 feature 단위로 API 계약을 나눕니다.

| 영역 | 모델 | Repository |
|---|---|---|
| 인증 | `features/auth/models/auth_models.dart` | `features/auth/repositories/auth_repository.dart` |
| 사원 | `features/admin/models/employee.dart` | `features/admin/repositories/admin_employee_repository.dart`, `features/employee/repositories/employee_repository.dart` |
| 부서/팀 | `features/admin/models/department_team_models.dart` | `features/admin/repositories/department_team_repository.dart` |
| 공통 등록 데이터 | 위 모델 재사용 | `features/admin/repositories/common_code_repository.dart` |
| 관리자 사원 등록 | auth/admin 모델 | `features/admin/repositories/signup_manage_repository.dart` |
| 휴가 | `features/leave/models/leave_request_models.dart` | `features/leave/repositories/leave_repository.dart` |
| 공휴일 | `features/leave/models/public_holiday.dart` | `features/leave/repositories/public_holiday_repository.dart` |
| 대시보드 | `features/dashboard/models/dashboard_models.dart` | `features/dashboard/repositories/dashboard_repository.dart` |

공통 Dio 인스턴스는 `lib/core/network/api_client.dart`에 있습니다.

## 5.2 주요 endpoint 계약

### 인증 / 내 정보

| Endpoint | Frontend 호출 |
|---|---|
| `POST /api/auth/signin` | `AuthRepository.signIn` |
| `POST /api/auth/signup` | `AuthRepository.signUp` |
| `POST /api/auth/forgot-password` | `AuthRepository.sendPasswordResetEmail` |
| `POST /api/auth/find-id` | `AuthRepository.findId` |
| `POST /api/auth/logout` | `FcmService.unregisterToken` |
| `GET /api/employees/me` | `AuthRepository.fetchMyInfo` |
| `PATCH /api/employees/me/email` | `EmployeeRepository.changeEmail` |
| `PATCH /api/employees/me/password` | `EmployeeRepository.changePassword` |

### 관리자 / 조직

| Endpoint | Frontend 호출 |
|---|---|
| `GET /api/admin/auth/common` | `CommonCodeRepository` |
| `POST /api/admin/auth/register` | `SignupManageRepository` |
| `GET /api/admin/employees/all` | `AdminEmployeeRepository` |
| `PUT /api/admin/employees/{employeeNumber}` | `AdminEmployeeRepository` |
| `PUT /api/admin/employees/{employeeNumber}/managed-teams` | `AdminEmployeeRepository` |
| `GET/POST/PUT/DELETE /api/admin/departments...` | `DepartmentTeamRepository` |
| `GET/POST/PUT/DELETE /api/admin/teams...` | `DepartmentTeamRepository` |

팀 목록은 Backend가 내려주는 `accessibleTeamInfo`의 `teamId/teamName/departmentId/departmentName` 관계를 사용합니다. Frontend가 팀명만 보고 부서를 추정하지 않습니다.

### 휴가 / 대시보드

| Endpoint | Frontend 호출 |
|---|---|
| `POST /api/leave-requests` | `LeaveRepository.submitLeaveRequest` |
| `GET /api/leave-requests/{requestId}` | `LeaveRepository.fetchLeaveRequestDetail` |
| `GET /api/leave-requests/my` | `LeaveRepository.fetchMyLeaveRequests` |
| `GET /api/leave-requests/all` | `LeaveRepository.fetchAllLeaveRequests` |
| `DELETE /api/leave-requests/{requestId}` | `LeaveRepository.cancelLeaveRequest` |
| `GET /api/leave-requests/my/period` | 휴가 화면의 서버 기준 연차기간 |
| `GET /api/admin/leave-requests/pending` | `LeaveRepository.fetchPendingLeaveRequests` |
| `GET /api/admin/leave-requests/{approved|rejected}` | `LeaveRepository.searchAdminLeaveRequests` |
| `POST /api/admin/leave-requests/{id}/approve` | `LeaveRepository.approveLeaveRequest` |
| `POST /api/admin/leave-requests/{id}/reject` | `LeaveRepository.rejectLeaveRequest` |
| `GET /api/dashboard` | `DashboardRepository.fetchDashboard` |

## 5.3 현재 일치가 확인된 핵심 계약

- 휴가 유형 코드는 Frontend와 Backend 모두 `FULL`, `AM_HALF`, `PM_HALF`, `ALTERNATIVE`, `PARENTAL`, `FAMILY`, `OTHER`를 사용합니다.
- 휴가/반려 사유는 Backend 최대 200자이며 Frontend 입력창도 `maxLength: 200`으로 맞춥니다.
- 휴가 상세의 `leaveReason`, 연차 snapshot 등 민감 정보는 Backend가 현재 조회 권한에 따라 null 처리하고 Frontend는 값이 있을 때만 표시합니다.
- `rejectReason`은 반려 상태이며 값이 실제로 존재할 때만 표시합니다.
- 현재 연차기간은 Frontend가 날짜를 하드코딩하지 않고 Backend `/my/period` 응답을 기준으로 사용합니다.
- 관리자별 관리팀 변경은 `expectedManagedTeams`와 최종 `managedTeams`를 함께 보내는 CAS 계약입니다.
- 팀 생성은 별도 `/api/admin/teams` 계약을 사용하며 사원 등록 요청이 암묵적으로 새 팀을 만들지 않습니다.

## 5.4 권한 경계

UI에서 관리자 메뉴를 숨기는 것은 편의 기능입니다. 실제 권한은 Backend가 판정합니다.

Backend의 `/api/admin/**`는 JWT에 저장된 로그인 시점 role만 믿지 않고 각 관리자 controller에서 현재 TeamManager/직급 상태를 다시 검증합니다. 따라서 Frontend가 보관한 role이나 화면 route 자체를 보안 경계로 간주하면 안 됩니다.

`GET /api/leave-requests/all`은 현재 일반 인증 사용자도 조회할 수 있는 요약 목록 API입니다. 휴가 사유와 개인 연차 snapshot은 이 목록 DTO에 포함되지 않으며 상세의 민감 필드는 별도 권한 정책으로 보호됩니다.

## 5.5 변경 시 점검

Backend DTO나 endpoint를 변경할 때는 다음을 함께 확인합니다.

- 대응 Frontend model의 nullability와 key 이름
- Repository request/response 테스트
- 관리자 권한 변경 시 현재 조직 기준 인가 유지 여부
- 휴가 사유 등 민감 필드가 목록 DTO로 확장되지 않는지
- Frontend/Backend CI 모두 성공하는지
