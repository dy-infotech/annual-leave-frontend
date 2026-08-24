# 부서 및 팀 관리 — 필요 API 스펙

`부서 및 팀 관리` 화면(`lib/screens/department_team_manage_screen.dart`)이 호출하는 API 정의서다.
프론트엔드는 아래 스펙을 전제로 구현되어 있고, **백엔드에는 아직 하나도 구현되어 있지 않다.**

---

## 1. 현재 백엔드 상태 (annual-leave-backend 확인 결과)

| 항목 | 실제 상태 |
|---|---|
| 부서 저장 위치 | `employee.department` **VARCHAR(50)** 자유 문자열. 부서 테이블 없음 |
| 부서 선택 목록 출처 | `common/type/DepartmentType.java` **자바 enum 하드코딩** (`대표이사`, `SI사업팀`) |
| 팀 저장 위치 | `team` 테이블 (`seq`, `team` VARCHAR(30), `project_manager_id` **NOT NULL** FK→employee, `parent_team` VARCHAR(30) **NOT NULL**) |
| 팀 서비스 | `TeamService.saveTeam()` 존재하나 **어떤 컨트롤러에도 노출되지 않음** |
| 부서/팀 컨트롤러 | **없음** (`DepartmentController`, `TeamController` 부재) |
| 현재 조회 경로 | `GET /api/admin/auth/common` → `{department: [String], team: [String], position: [String]}` — 이름만, 그나마 팀은 요청자의 팀+하위 팀만 필터링됨 |

### 선결 과제 2가지

1. **부서 추가/수정은 지금 구조로 불가능하다.** enum 상수라 소스 수정 + 재배포가 필요하다.
   화면에서 부서를 관리하려면 `department` 테이블 신설과 기존 `employee.department` 문자열
   데이터 마이그레이션이 선행되어야 한다.
2. **팀 하나에 관리자가 여러 명이면 같은 `team` 이름으로 행이 여러 개 생긴다** (유니크 제약 없음,
   `findAllByTeam` 이 `List<Team>` 반환). API 응답에서는 이 행들을 팀 이름으로 묶어
   `managers` 배열로 내려주기를 기대한다. 안 묶어주면 화면에 같은 팀이 중복 표시된다.

---

## 2. 필요한 엔드포인트

모두 관리자 전용이며 기존 `/api/admin/**` 규칙을 따른다고 가정했다.

### 2-1. 부서

#### `GET /api/admin/departments`

```jsonc
[
  { "departmentId": 1, "departmentName": "대표이사", "teamCount": 1 },
  { "departmentId": 2, "departmentName": "SI사업팀", "teamCount": 3 }
]
```

`teamCount` 는 선택 항목이다(없으면 목록에 표시하지 않음).
`departmentId` 가 **없으면 화면은 수정 기능을 비활성화**한다.

#### `POST /api/admin/departments`

```jsonc
{ "departmentName": "신규사업팀" }
```

#### `PUT /api/admin/departments/{departmentId}`

```jsonc
{ "departmentName": "수정된부서명" }
```

성공은 `200` 또는 `204`. 실패 시 `{ "message": "..." }` 를 담아 4xx/5xx —
`ApiClient` 인터셉터가 `message` 를 꺼내 화면에 노출한다.

### 2-2. 팀

#### `GET /api/admin/teams`

```jsonc
[
  {
    "teamId": 1,
    "teamName": "스마트팩토리구축사업",
    "parentTeam": "대표이사",
    "managers": [
      { "employeeNumber": "A2020001", "name": "이호영", "position": "이사" }
    ]
  }
]
```

#### `POST /api/admin/teams`

```jsonc
{
  "teamName": "신규팀",
  "parentTeam": "대표이사",
  "managerEmployeeNumbers": ["A2020001"]
}
```

#### `PUT /api/admin/teams/{teamId}`

동일한 body.

**`managerEmployeeNumbers` 는 항상 1건 이상이다** (화면에서 검증). 서버도 빈 배열을 거절해야
`project_manager_id NOT NULL` 제약과 어긋나지 않는다.

---

## 3. 백엔드에 확인이 필요한 사항

1. **팀 생성 시 관리자를 함께 받을 수 있는가.** 위 스펙처럼 `managerEmployeeNumbers` 를 한 번에
   받으면 원자적으로 처리된다. 못 받으면 프론트가 팀 생성 → 관리자 수만큼
   `PUT /api/admin/employees/{empNo}` 를 순차 호출해야 하는데, **중간 실패 시 관리자 없는 팀이
   남는다.** 가능하면 한 번에 받는 쪽으로.
2. **`teamId` / `departmentId` 를 내려줄 수 있는가.** 현재 프로젝트는 부서·팀을 전부 이름
   문자열로만 다룬다. 그래서 `admin-settings.dart:85-98` 은 DB 동명 팀을 `'대표이사 (1)'`,
   `'대표이사 (2)'` 로 클라이언트가 임의 구분한 뒤 **그 가짜 이름을 그대로 서버에 전송**하고 있다
   (기존 잠재 버그). 이름을 키로 쓰는 한 '이름 수정'은 원리적으로 안전하지 않으므로 id 가 필요하다.
3. **`parentTeam` 을 무엇으로 채울 것인가.** 스키마상 NOT NULL 이고, 시드 데이터에서 루트 팀
   `대표이사` 는 자기 자신을 상위 팀으로 갖는다. 최초 팀 생성 시 규칙 확인 필요.
4. **`/api/admin/auth/common` 의 팀 필드명.** 로컬 백엔드 DTO 는 `team` 인데 프론트 코드는
   `accessibleTeam` 을 읽는다(`search_employee_number_screen.dart:36` 은 둘 다 대비).
   배포본 기준 정본이 무엇인지 확인 필요.
5. **삭제 API.** 이번 요구사항에 없어 만들지 않았으나, 잘못 추가한 부서/팀을 되돌릴 수단이
   전혀 없다는 점은 기획에 공유가 필요하다.

---

## 4. API 부재 시의 화면 동작 (구현되어 있음)

`GET /api/admin/departments` 또는 `GET /api/admin/teams` 가 실패하면 화면은
`GET /api/admin/auth/common` 으로 폴백해 **이름 목록만 표시**한다(두 탭이 이 호출을 공유한다).

이 폴백 상태에서는 id 를 알 수 없고 쓰기 API 도 없으므로 **추가·수정 진입을 모두 막는다.**
탭 상단에 안내 문구를 띄우고, 추가 버튼은 비활성, 목록 항목은 탭 반응과 `>` 아이콘을 주지 않는다.
즉 **위 6개 엔드포인트가 생기기 전까지 이 화면은 조회 전용으로 동작한다.**

## 5. 프론트엔드가 이미 강제하는 검증

서버가 아래를 어겨도 되도록 설계할 생각이라면 프론트도 함께 고쳐야 한다.

| 항목 | 화면 동작 | 근거 |
|---|---|---|
| 팀 관리자 | 최소 1명 없으면 저장 불가 | `team.project_manager_id NOT NULL` |
| 상위 팀 | 미선택 시 저장 불가 | `team.parent_team NOT NULL` |
| 팀명 / 부서명 | 공백 불가 | — |

> 미해결 엣지 케이스: 팀이 하나도 없는 상태에서는 상위 팀 후보가 비어 최초 팀을 만들 수 없다.
> 시드 데이터의 루트 팀 `대표이사` 는 자기 자신을 상위 팀으로 갖는데, 이 규칙을 API 스펙으로
> 확정해 주면(예: `parentTeam` 생략 시 서버가 자기 자신으로 채움) 프론트에서 처리하겠다.
