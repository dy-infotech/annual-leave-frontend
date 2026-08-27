# 부서 및 팀 관리 — API 명세

`부서 및 팀 관리` 화면(`lib/screens/ADM003_M01.dart`)이 호출하는 API 정의서다.
백엔드 `feature/department-team-admin-api` 브랜치(PR #57) 기준으로 확정된 스펙이며,
프론트엔드 호출 코드는 `lib/services/department_team_api.dart` 에 모여 있다.

## 공통 사항

- 인증: `Authorization: Bearer {JWT}`, 요청 바디는 `Content-Type: application/json`
- 권한: 전 엔드포인트 **대표이사(사장)만** 호출 가능. 그 외 계정은 `403`
- 소프트 딜리트: 삭제된(비활성) 부서/팀은 조회 응답에 나타나지 않음
- 에러 응답: `{ "error": "...", "message": "...", "path": "...", "status": 400, "timestamp": "..." }`
  — `message` 를 그대로 사용자에게 노출하면 된다 (`ApiClient` 인터셉터가 `DioException.message` 로 옮겨 둠)

| 상태 | 공통 의미 |
|---|---|
| 403 | 대표이사가 아님 — `"인사권을 가진 관리자가 아닙니다."` |
| 404 | 대상(부서/팀/사원) 없음 |
| 409 | 이름 중복 (부서명/팀명 UNIQUE) |
| 400 | 검증 실패 — `message` 에 사유가 담김 |

## 부서

### `GET /api/admin/departments` — 전체 부서 조회

```jsonc
[
  { "departmentId": 1, "departmentName": "SI사업팀", "enabled": true },
  { "departmentId": 2, "departmentName": "대표이사", "enabled": true }
]
```

### `POST /api/admin/departments` — 부서 등록

요청: `{ "departmentName": "신규사업팀" }` (필수, 50자 이하, 앞뒤 공백은 서버가 제거)
응답 200: `{ "departmentId": 3 }`
에러 409: 이미 존재하는 부서명입니다.

### `PUT /api/admin/departments/{departmentId}` — 부서명 변경

요청: `{ "departmentName": "수정된부서명" }` (필수, 50자 이하)
에러 400: 대표이사 부서명은 변경할 수 없습니다. / 409: 이미 존재하는 부서명입니다.

### `DELETE /api/admin/departments/{departmentId}` — 부서 소프트 딜리트

이미 삭제된 부서에 다시 호출해도 200 (멱등).
에러 400: 대표이사 부서는 삭제할 수 없습니다. /
소속된 활성 팀이 있는 부서는 삭제할 수 없습니다. 팀을 먼저 정리해주세요.

## 팀

### `GET /api/admin/teams` — 전체 팀 조회 (소속 부서·담당자·상위 팀 포함)

```jsonc
[
  {
    "teamId": 1,
    "teamName": "스마트팩토리구축사업",
    "enabled": true,
    "departmentId": 1,
    "departmentName": "SI사업팀",
    "parentTeamId": 2,
    "parentTeamName": "대표이사",
    "managers": [
      { "employeeId": 4, "employeeNumber": "A2020001", "name": "이호영", "position": "이사" }
    ]
  }
]
```

대표이사 팀(루트)은 상위 팀이 자기 자신이다 (`parentTeamId == teamId`).

### `POST /api/admin/teams` — 팀 등록

| 필드 | 타입 | 제약 |
|---|---|---|
| `teamName` | string | 필수, 30자 이하 |
| `projectManagerId` | number | 필수 — 담당자(PM)로 지정할 사원 id (`employeeId`) |
| `departmentId` | number | 필수 — 소속 부서 (부서:팀 = 1:N) |
| `parentTeamId` | number | 옵션 — 미지정 시 대표이사 팀이 상위 팀 |

응답 200: `{ "teamId": 5 }`
에러 400: 소속 부서가 존재하지 않습니다. / 비활성화된 부서에는 팀을 등록할 수 없습니다. /
상위 팀이 존재하지 않습니다. · 404: 담당자로 지정할 사원이 존재하지 않습니다. · 409: 이미 존재하는 팀명입니다.

### `PUT /api/admin/teams/{teamId}` — 팀 수정

모든 필드가 옵션이며, 보내지 않은(null) 필드는 기존 값을 유지한다.

| 필드 | 동작 |
|---|---|
| `teamName` | 팀명 변경 (30자 이하) |
| `projectManagerId` | 담당자 교체 — 기존 담당자 전원이 이 사원 1명으로 교체됨 |
| `departmentId` | 소속 부서 변경 — 소속 사원 전원의 부서도 함께 변경됨 |
| `parentTeamId` | 상위 팀 변경 (결재선 변경) |

에러 400: 자기 자신을 상위 팀으로 지정할 수 없습니다. / 해당 팀의 하위 팀은 상위 팀으로 지정할 수 없습니다. /
상위 팀·부서 부재, 비활성 부서 · 404: 팀/사원 없음 · 409: 이미 존재하는 팀명입니다.

### `DELETE /api/admin/teams/{teamId}` — 팀 소프트 딜리트

담당자(결재선) 정보도 함께 제거. 재호출 시 200 (멱등).
에러 400: 하위 팀이 있는 팀은 삭제할 수 없습니다. / 소속 사원이 있는 팀은 삭제할 수 없습니다.

## 연동 참고

- 담당자 선택: `GET /api/admin/employees/all` (사원 목록) 사용.
  **주의:** `projectManagerId` 는 숫자 `employeeId` 인데, 이 응답에 `employeeId` 필드가
  포함되어야 담당자 지정이 가능하다 (`EmployeeDto.EmployeeResponse` 에 추가 필요).
  프론트는 `employeeId` 가 없으면 저장을 막고 안내 문구를 보여준다.
- 부서 선택: `GET /api/admin/departments` 사용
- 대표이사 부서는 이름 기준(`대표이사`)으로 식별되어 수정·삭제가 거부된다.
  화면도 같은 규칙으로 메뉴를 숨긴다 (`kCeoName`).
- 기존 `POST /api/admin/auth/common`(부서·팀 동시 등록)은 이 API들로 대체 예정 —
  신규 화면에서는 사용하지 않는다.
