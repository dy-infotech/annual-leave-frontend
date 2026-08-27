# 05. 데이터 모델 및 API 연동

## 5.1 모델 (`lib/models/`)

모두 수동으로 `fromJson`/`toJson`을 구현합니다(코드 생성기·`json_serializable` 미사용).

| 파일 | 클래스 | 대응 백엔드 응답/요청 |
|---|---|---|
| `auth_models.dart` | `LoginRequest`, `LoginResponse`, `SignUpRequest`, `AdminAuthRegisterRequest` | `SignInDto`, `SignUpDto`, `RegisterDto` |
| `employee.dart` | `Employee` | `EmployeeDto.EmployeeResponse` |
| `dashboard_models.dart` | `LeaveInfo`, `LeaveRequestSummary`, `DashboardData` | `DashboardDto` |
| `leave_request_models.dart` | `LeaveRequestCreate`, `LeaveRequestListItem`, `PendingLeaveRequest` | `LeaveRequestDto`, `LeaveRequestListDto`, `PendingLeaveRequestDto` |
| `public_holiday.dart` | `PublicHoliday` | `SpecialDayDto.SpecialDayResponse` |
| `enums/LeaveState.dart` | `LeaveState`(code/label) | `LeaveRequestStatus` |
| `enums/LeaveType.dart` | `LeaveType`(code/label) | `LeaveType` — ⚠️ [§5.4](#54-알려진-불일치-크로스-레포-검증-결과) 참조 |
| `enums/RoleType.dart` | `RoleType`(code/label) | `Role` |

### 검증된 정확한 매칭 (백엔드 소스와 필드 단위 대조)
- `Employee.fromJson` ↔ 백엔드 `EmployeeDto.EmployeeResponse`(`annual-leave-backend/.../dto/EmployeeDto.java`): `employeeNumber, name, department, position, email, hireDate, role, currTotalLeaveDays, remainingLeaveDays, approverNumber, approverName, approverPosition, approverDepartment, isRegisted` — **필드명 1:1 일치**.
- `DashboardData.fromJson` ↔ 백엔드 `DashboardDto`: `myLeaveInfoResponse`(→ `LeaveInfo`), `myRequestSummary`(→ `LeaveRequestSummary`), `allEmployeeRequestSummary`(nullable) — **필드명 일치**. 다만 백엔드 소스에도 `myLeaveInfoResponse`만 `Response` 접미사가 붙고 `myRequestSummary`는 붙지 않는 **비일관적 네이밍**이 원본 그대로이므로, 향후 백엔드 리네이밍 시 프론트도 함께 깨질 수 있습니다.

이처럼 현재는 정확히 맞물려 있으나, **타입 자동생성이나 공유 스키마가 없어** 백엔드 필드명이 바뀌면 프론트가 조용히 깨집니다(컴파일 에러 없이 `null` 처리됨 — Dart 쪽이 `?? ''`/`?? 0.0` 기본값으로 방어하는 필드가 많아 런타임에 드러나지 않을 수 있음).

## 5.2 HTTP 클라이언트

`lib/services/api_client.dart` — dio 싱글턴 하나. 요청 인터셉터가 `flutter_secure_storage`의 `jwt_token`을 읽어 `Authorization: Bearer` 자동 첨부, 응답 에러 인터셉터가 백엔드 `ErrorResponse.message`를 추출해 `DioException.message`에 덮어씁니다(단, 실제로 화면에서 이 메시지를 쓰는 곳은 적음 — [04 §4.9](04-screens-catalog.md#49-공통-ui-패턴) 참조).

## 5.3 엔드포인트 매핑표

별도 서비스 레이어가 없어 호출부가 Provider/화면에 흩어져 있습니다([03 §3.2](03-app-architecture.md#32-레이어링)). 백엔드 [08-api-conventions.md](../../annual-leave-backend/docs/08-api-conventions.md)의 전체 목록과 대조한 결과입니다.

| 백엔드 엔드포인트 | 프론트 호출 위치 |
|---|---|
| `POST /api/auth/signup` | `AuthProvider.signUp()` ← `signup_screen.dart` |
| `POST /api/auth/signin` | `AuthProvider.login()` ← `login_screen.dart` |
| `POST /api/auth/forgot-password` | `AuthProvider.sendPasswordResetEmail()` ← `forgotPasswordScreen.dart` |
| `POST /api/auth/find-id` | `AuthProvider.findId()` ← `forgotPasswordScreen.dart` |
| `POST /api/auth/logout` | **호출하는 곳 없음** — 아래 참조 |
| `GET /api/admin/auth/common` | `signup_manage_screen.dart`(`ApiClient` 직접 호출) |
| `POST /api/admin/auth/register` | `AuthProvider.adminAuthRegister()` ← `signup_manage_screen.dart` |
| `GET /api/admin/employees/all` | `search_employee_number_screen.dart`(직접 호출, `searchParam` 쿼리) |
| `GET /api/employees/me` | `AuthProvider.fetchMyInfo()` ← 로그인 성공 시, `tryAutoLogin()` |
| `PATCH /api/employees/me/modify-email` | `my_info_screen.dart`(직접 호출) |
| `PATCH /api/employees/me/password` | `my_info_screen.dart`(직접 호출) |
| `GET /api/leave-requests/current-year-special-days` | `PublicHolidayProvider.fetchPublicHoliday()` |
| `GET /api/leave-requests/next-year-special-days` | `PublicHolidayProvider.fetchPublicHoliday()` |
| `POST /api/leave-requests` | `leave_request_screen.dart`(직접 호출) |
| `GET /api/leave-requests/all` | `all_leave_requests_screen.dart`("전체" 필터 선택 시, 직접 호출) — ⚠️ [§5.4](#54-알려진-불일치-크로스-레포-검증-결과) |
| `GET /api/leave-requests/my` | `LeaveRequestListProvider.fetchMyLeaveRequestList()`, `all_leave_requests_screen.dart`("내 신청" 필터) |
| `DELETE /api/leave-requests/{id}` | `all_leave_requests_screen.dart`(직접 호출) |
| `GET /api/admin/leave-requests/pending` | `pending_approval_screen.dart`(직접 호출) |
| `POST /api/admin/leave-requests/{id}/approve` | `pending_approval_screen.dart`(직접 호출) |
| `POST /api/admin/leave-requests/{id}/reject` | `pending_approval_screen.dart`(직접 호출) |
| `GET /api/dashboard` | `DashboardProvider.fetchDashboard()` |

**`POST /api/auth/logout`을 프론트가 호출하지 않습니다.** `AuthProvider.logout()`은 로컬 JWT 삭제(`clearToken()`)와 상태 초기화만 수행하고 백엔드에 알리지 않습니다. 백엔드의 로그아웃 엔드포인트는 주로 FCM 토큰 정리 용도인데, 프론트에 FCM 자체가 미구현이라 현재는 실질적 영향이 적지만, 백엔드에 서버측 세션/토큰 무효화 로직이 추가되면 이 누락이 문제가 될 수 있습니다.

## 5.4 알려진 불일치 (크로스 레포 검증 결과)

이 저장소와 `annual-leave-backend`를 직접 대조해 발견한, **실제 동작에 영향을 줄 수 있는** 두 가지입니다.

### ① `LeaveType` 코드값 불일치 — 잠재적 400 오류

프론트 enum(`lib/models/enums/LeaveType.dart`):
```dart
alternate('ALTERNATE', '대체 휴가'),
parental('PARENTAL', '출산 휴가'),
```
백엔드 enum(`annual-leave-backend/.../common/type/LeaveType.java`):
```java
ALTERNATIVE ("ALTERNATIVE", "대체 휴가"),
PERENTAL    ("PERENTAL",    "출산 휴가"),
```
백엔드 `LeaveRequestService.createLeaveRequest`는 `LeaveType.fromName(request.getLeaveType())`으로 문자열을 조회하며, 일치하는 이름이 없으면 **400 "휴가유형 파라미터가 잘못되었습니다."**를 반환합니다. 프론트가 `POST /api/leave-requests`에 `leaveType: "ALTERNATE"` 또는 `"PARENTAL"`을 보내면 백엔드 맵에 `"ALTERNATIVE"`/`"PERENTAL"`만 있으므로 **"대체 휴가"와 "출산 휴가" 두 유형은 신청이 항상 실패**합니다. FULL/AM_HALF/PM_HALF/FAMILY/OTHER는 코드값이 동일해 문제없습니다.

**해결 방향**: 어느 쪽이 정답인지는 정책 결정 필요(백엔드 enum명을 스키마 주석 철자에 맞출지, 프론트를 백엔드에 맞출지). 프론트만 고친다면 `lib/models/enums/LeaveType.dart`의 `alternate`/`parental` 코드값을 `ALTERNATIVE`/`PERENTAL`로 수정하면 됩니다.

### ② `/api/leave-requests/all` 권한 범위 — 일반 직원도 전직원 신청 내역 조회 가능

백엔드 `SecurityConfig`는 `/api/admin/**`만 `hasRole(ADMIN)`으로 제한하고, `/api/leave-requests/all`은 `/api/admin/**` 밖에 있어 **인증만 되면(일반 직원도) 호출 가능**합니다. 백엔드 서비스(`LeaveRequestService.searchLeaveRequests`)도 요청자의 역할을 검사하지 않습니다.

프론트 `AllLeaveRequestsScreen`의 "전체"/"내 신청" 라디오 버튼도 `auth.isAdmin` 조건 없이 **모든 로그인 사용자에게 노출**됩니다([04 §4.6](04-screens-catalog.md#46-allleaverequestsscreen-all-leave-requests) 참조). 즉 일반 직원이 "전체"를 선택하면 전 직원의 휴가 신청 내역(이름/부서/기간/상태)을 조회할 수 있습니다 — 의도된 동작인지 확인이 필요합니다. 의도치 않았다면 백엔드에 인가 제한 추가 또는 프론트에서 `auth.isAdmin`일 때만 "전체" 옵션을 노출하는 조치가 필요합니다.

## 5.5 주의점 / 제안

- **서비스 레이어 통합**: `lib/services/`에 기능별(auth/leave-request/admin) API 함수를 모아 Provider·화면의 직접 `ApiClient().dio.xxx()` 호출을 줄이면 유지보수성이 향상됩니다.
- **공유 타입 부재**: OpenAPI 스펙(백엔드 springdoc 활성화 시 산출 가능 — [백엔드 08 §8.7](../../annual-leave-backend/docs/08-api-conventions.md#87-자동-생성-도구-연동-제안-문서화--이번-회차-코드-변경-없음))을 프론트 코드젠에 연결하면 위 5.1의 "조용히 깨지는" 리스크를 구조적으로 줄일 수 있습니다.
- **①/② 항목은 우선 확인·수정 권장**(버그 또는 의도치 않은 권한 노출 가능성).
