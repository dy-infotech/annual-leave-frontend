# 부서 및 팀 관리 — develop_v2.0 API 명세

Frontend 구현:

- 화면: `lib/features/admin/views/ADM003_M01.dart`
- ViewModel: `lib/features/admin/view_models/ADM003_M01_view_model.dart`
- Repository: `lib/features/admin/repositories/department_team_repository.dart`
- 모델: `lib/features/admin/models/department_team_models.dart`

Backend 실제 계약은 `develop_v2.0`의 `AdminDepartmentController`, `AdminTeamController`, `DepartmentDto`, `TeamDto`가 정본입니다.

## 공통 권한 / 오류

- 인증: `Authorization: Bearer {JWT}`
- `/api/admin/**`는 Backend `AdminAuthorizationInterceptor`가 현재 관리자 상태를 확인합니다.
- 부서/팀 컨트롤러는 `@RequirePersonnelAuthority` 대상이므로 현재 인사권도 필요합니다.
- Frontend 메뉴/role은 UX일 뿐 최종 인가 근거가 아닙니다.
- 서버 오류의 `message`는 `ApiClient`가 `DioException.message`에 보존합니다.

일반적인 상태:

| 상태 | 의미 |
|---|---|
| 400 | 요청값/조직 정책 검증 실패 |
| 401 | 인증 실패/만료 |
| 403 | 현재 관리자/인사권 부족 |
| 404 | 대상 부서/팀/사원 없음 |
| 409 | 중복 이름, idempotency 충돌, 동시 상태 충돌 |

## 부서

### GET `/api/admin/departments`

활성 부서 목록을 조회합니다.

응답 한 건:

```json
{
  "departmentId": 1,
  "departmentName": "SI사업팀",
  "enabled": true
}
```

### POST `/api/admin/departments`

```json
{ "departmentName": "신규사업팀" }
```

- 필수
- 최대 50자
- 성공 시 `departmentId` 반환

### PUT `/api/admin/departments/{departmentId}`

```json
{ "departmentName": "변경된부서명" }
```

대표이사 보호 정책, 이름 중복, 활성 조직 제약을 Backend가 검증합니다.

### DELETE `/api/admin/departments/{departmentId}`

소프트 삭제입니다. 활성 팀이 남아 있는 등 조직 제약을 Backend가 검증합니다.

## 팀

### GET `/api/admin/teams`

응답에는 팀/부서/상위 팀과 복수 관리자 목록이 포함됩니다.

```json
{
  "teamId": 2,
  "teamName": "스마트팩토리구축사업",
  "enabled": true,
  "departmentId": 1,
  "departmentName": "SI사업팀",
  "parentTeamId": 1,
  "parentTeamName": "대표이사",
  "managers": [
    {
      "employeeId": 4,
      "employeeNumber": "A2020001",
      "name": "이호영",
      "position": "이사",
      "active": true
    }
  ]
}
```

담당자가 없는 팀은 `managers: []`이며 TeamManager row가 없으므로 상위 결재선 정보도 없을 수 있습니다.

### POST `/api/admin/teams`

요청 필드:

| 필드 | 필수 | 설명 |
|---|---|---|
| `teamName` | O | 최대 30자 |
| `departmentId` | O | 활성 부서 ID |
| `projectManagerId` | X | 담당자 없이 팀만 먼저 생성 가능 |
| `parentTeamId` | X | 담당자를 함께 지정할 때만 사용 |

담당자 없이 생성:

```json
{
  "teamName": "품질관리팀",
  "departmentId": 2
}
```

담당자와 함께 생성:

```json
{
  "teamName": "품질관리팀",
  "departmentId": 2,
  "projectManagerId": 15,
  "parentTeamId": 1
}
```

- `projectManagerId == null`인데 `parentTeamId`만 지정하면 400입니다.
- 담당자를 지정하고 `parentTeamId`를 생략하면 Backend가 대표이사 팀을 기본 상위 팀으로 사용합니다.
- Frontend는 생성 요청에 `Idempotency-Key`를 보냅니다. 같은 키+같은 요청은 같은 생성 결과로 수렴하고, 같은 키를 다른 요청에 재사용하면 409입니다.

### PUT `/api/admin/teams/{teamId}`

모든 필드는 선택입니다.

| 필드 | 동작 |
|---|---|
| `teamName` | 팀명 변경 |
| `departmentId` | 부서 변경 및 소속 직원 부서 정합성 갱신 |
| `projectManagerId` | 기존 담당자들을 지정한 1명으로 교체 |
| `parentTeamId` | 현재 TeamManager들의 상위 결재선 변경 |

관리자 없는 팀에 최초 담당자를 지정하면서 `parentTeamId`를 생략하면 대표이사 팀이 기본 상위 팀이 됩니다.

### DELETE `/api/admin/teams/{teamId}`

소프트 삭제입니다. 하위 팀/소속 직원 등 삭제 불가 조건은 Backend가 검증합니다.

## 담당자 선택

담당자 검색은 `GET /api/admin/employees/all`을 사용합니다. 현재 응답의 `Employee` 모델에는 `employeeId`가 포함되어 있어 `projectManagerId`로 바로 사용할 수 있습니다.

Frontend는 입사 전/퇴사 처리된 직원을 담당자로 선택하지 않도록 1차 필터링하고, Backend가 최종 검증합니다.

## 사용자 등록과의 관계

`POST /api/admin/auth/register`는 존재하는 팀만 사용합니다. 사원 등록 요청이 새 팀을 암묵적으로 만들지 않습니다.

`GET /api/admin/auth/common`은 등록/수정 화면의 접근 가능한 부서·팀·직급 공통데이터 용도로 계속 사용하며, 부서/팀 CRUD API를 대체하는 endpoint가 아닙니다.
