# MVVM 마이그레이션 계획 (절충안)

## 확정 아키텍처

feature-first MVVM을 기본으로 하고, 클린 아키텍처에서 두 가지만 가져온다.

- `core/error/`의 공통 에러 모델: `Failure` + `Result<T>`. Repository가 DioException을 잡아 Failure로 변환해 반환한다.
- 선별 UseCase: 검증 규칙을 가진 동작만 순수 클래스로 분리한다. 대상은
  `submit_leave_request`(중복 신청, 잔여연차, 반차 조합 검증)와
  `decide_signup`(등록 승인) 두 개다.

그 외 원칙:

- Repository는 구체 클래스로 두고 인터페이스를 만들지 않는다. 테스트 더블은
  Dart의 암묵적 인터페이스(`implements`)로 만든다.
- ViewModel은 화면당 1개, ChangeNotifier, Repository를 생성자로 주입받는다.
- 화면 파일명은 화면 코드 체계를 유지하고, ViewModel 파일명은
  `<화면코드>_view_model.dart`로 짝을 맞춘다.
- 전역 Provider는 `AuthSession` 하나만 앱 루트에 남긴다. 화면 ViewModel은
  화면 진입 시 생성한다.

최종 디렉터리 구조와 파일 구성은 별도 설계 논의 결과를 따른다
(`lib/app`, `lib/core`, `lib/features/{auth,dashboard,leave,employee,admin}`).

## 동일 동작 보장 체계

기존 코드는 정상 동작 중이므로, "변경 후에도 이전과 동일하게 동작"을 다음
다섯 겹으로 보장한다. 각 단계의 완료 조건(게이트)에 모두 반영되어 있다.

### 1) 이동 커밋과 변경 커밋의 분리

파일 이동/코드 이동만 하는 커밋에는 로직 변경을 한 줄도 섞지 않는다.
이동 커밋은 아래 명령으로 "글자 그대로 옮겨졌는지"를 기계적으로 검증할 수 있다.

```bash
git diff --color-moved=dimmed-zebra HEAD~1
```

이동된 블록은 회색으로 표시되므로, 색이 있는 줄(실제 변경)이 import 문
외에 없는지만 확인하면 된다.

### 2) 컴파일러/analyzer/빌드 게이트

매 단계 완료 시 다음이 통과해야 한다.

```bash
flutter analyze
flutter test
flutter build web --release
```

### 3) 특성화 테스트 (characterization test)

화면 로직을 건드리기 전에 현재 동작을 테스트로 먼저 기록한다. 현재 구조에서는
화면이 dio를 직접 호출해 테스트가 불가능하므로, 화면마다 다음 3박자를 반복한다.

1. repository 추출: 화면 안의 dio 호출을 메서드/경로/페이로드 구성 코드까지
   글자 그대로 repository로 옮긴다. 리팩터링 금지. (이동 커밋)
2. 특성화 테스트 작성: 페이크 repository를 주입해 현재 화면 동작(렌더링,
   흐름, 에러 메시지)을 위젯 테스트로 기록한다. (테스트 커밋)
3. ViewModel 추출: 화면에는 build만 남기고 상태/로직을 VM으로 옮긴다.
   2에서 작성한 테스트가 무수정으로 green이어야 한다. (변경 커밋)

가장 위험한 3번 단계가 항상 테스트 그물 위에서 일어나는 것이 핵심이다.

### 4) 기존 테스트의 기준선 역할

`test/ADM003_M01_test.dart`(부서/팀 관리, 시나리오 13개)는 마이그레이션
전 과정에서 시나리오 무수정 원칙으로 유지한다. 주입 방식(static instance
교체 -> 생성자 주입)과 import 경로만 바꾸고, expect와 시나리오 본문은
바꾸지 않는다. 이 테스트가 깨지면 동작이 달라진 것이다.

### 5) 수동 스모크 체크리스트

자동화가 불가능하거나 실서버/실기기가 필요한 항목은 수동 확인한다.
기능 단위 마이그레이션이 끝날 때마다 해당 기능 행을 수행하고, 마지막
auth 분해 후에는 전체를 1회 수행한다.

| 화면 | 확인 시나리오 |
|---|---|
| AUT001 로그인 | 정상 로그인, 실패 메시지, 사번 대문자 자동 변환, 계정 정보 저장 후 재실행 시 자동 입력 |
| AUT002 사용자 등록 | 등록 신청, 실패 메시지 |
| AUT003 계정 찾기 | 아이디 찾기, 비밀번호 재설정 메일, 탭 전환 |
| 자동 로그인 | 로그인 후 앱 재시작 시 대시보드 직행, 로그아웃 후 재시작 시 로그인 화면 |
| DSH001 대시보드 | 잔여연차/현황 표시, 관리자 대기 건 클릭 시 결재 대기 이동, 뒤로 왔을 때 갱신 |
| FCM | 로그인 후 토큰 1회 등록(중복 등록 없음), 알림 수신, 알림 거부 상태에서 로그인 가능 |
| LVE001 휴가 신청 | 종일/반차 신청, 같은 날 오전+오후 반차 허용, 중복 신청 차단, 잔여연차 초과 차단, 공휴일 표시, 신청 후 화면 유지+갱신 |
| LVE002_M01 내 목록 | 목록 조회, 신청 취소 |
| LVE002_M02 전직원 목록 | 기간 조회, 팀 필터, 건수 표시, 상세 진입 |
| LVE002_M03 관리자 검색 | 사번/사원명 검색, 연도 범위 검증 |
| LVE002_D01 상세 | 신청/결재 내역 표시 |
| LVE003 결재 대기 | 목록 조회, 승인, 반려, 처리 후 목록 갱신 |
| EMP001 내 정보 | 정보 표시, 이메일 변경(형식 검증, 도메인 자동완성), 변경 후 재조회 |
| ADM001 관리팀 설정 | 조회, 변경 저장 후 재진입 시 반영 |
| ADM002 등록 관리 | 목록 조회, 승인(역할/입사일 처리), 대표 계정 역할 선택 규칙 |
| ADM003 부서/팀 | 자동 테스트로 커버. 수동은 실서버 CRUD 1회 |
| ADM004 사번 조회/상세 | 검색, 상세 수정, 대표 본인 정보 수정 제한 |
| 공통 | 드로어 메뉴 역할별 노출, 각 화면 라우트 진입, 로그아웃 |

주의: 세션 만료/토큰 관련 동작은 로그인 상태를 오래 유지한 채 확인이
어려우므로, auth 분해 단계에서 토큰 삭제 후 API 호출 시의 동작을 별도 확인한다.

### 보조 수단: 요청 로그 비교 (선택)

repository 추출이 특히 불안한 화면은 디버그 전용 dio 인터셉터로
요청(메서드, 경로, 바디)을 콘솔에 남기고, 이동 전/후에 같은 시나리오를
수행해 로그를 비교한다. 1단계에서 `ApiClient`에 `kDebugMode` 조건부
`LogInterceptor`를 넣어두면 이후 전 단계에서 활용할 수 있다.

## 단계별 계획

단계당 PR 1개(develop 대상)를 원칙으로 하고, 어떤 PR이 머지된 시점에도
앱은 배포 가능한 상태여야 한다. 규모는 S(반나절 이하), M(1일 내외),
L(2~3일)로 표기한다.

### 0단계: 안전망 구축 (S)

기존 코드를 건드리지 않고 그물부터 친다.

- CI 워크플로우 신설(`.github/workflows/ci.yml`): develop/main 대상 PR에서
  `flutter analyze` + `flutter test` 실행. 현재 deploy.yml에는 테스트
  단계가 없다.
- `core/error/failure.dart`, `core/error/result.dart` 추가 (신규 파일이라 무위험)
- 테스트 인프라: `test/helpers/pump_app.dart`(테마+Provider 래핑, 무한
  애니메이션 대응 pump 루프 -- 기존 ADM003 테스트의 헬퍼를 승격),
  `test/helpers/fixture_reader.dart`, `test/fixtures/` 골격
- `ApiClient`에 디버그 전용 요청 로거 추가 (선택)

게이트: 기존 테스트 통과, 앱 동작 무변경(코드 경로 미접촉).

### 1단계: 뼈대 이동 (S, 타이밍 조율 필요)

순수 파일 이동만. 로직 변경 0.

- `services/api_client.dart` -> `core/network/`,
  `config/api_config.dart` -> `core/config/`,
  `theme/app_theme.dart` -> `core/theme/`,
  `widgets/app_drawer.dart` -> `core/widgets/`
- `main.dart`에서 `app/app.dart`(MyApp, 라우트 테이블, routeObserver)와
  `features/auth/views/splash_screen.dart` 분리
- 전체 import 경로 일괄 수정

게이트: `--color-moved` 리뷰에서 import 외 변경 없음, analyze/build 통과,
전 화면 진입 스모크.

주의: 대량 이동이라 진행 중인 다른 브랜치와 충돌이 크다. 원격에 활성
feature 브랜치가 다수이므로, 머지 대기 중인 PR을 정리한 직후 하루 안에
끝내고 바로 머지한다. 2단계도 같은 성격이므로 연달아 진행한다.

### 2단계: 모델 분배와 파싱 테스트 (M)

- `models/` 파일들을 기능별로 이동:
  auth_models(+RoleType) -> `features/auth/models/`,
  dashboard_models -> `features/dashboard/models/`,
  leave_request_models, public_holiday, LeaveType, LeaveState -> `features/leave/models/`,
  employee, department_team_models -> `features/admin/models/`
- fixture JSON 기반 fromJson/toJson 파싱 테스트를 전 모델에 작성해
  파싱 동작을 고정

게이트: 1단계와 동일 + 파싱 테스트 green.

### 3단계: leave 기능 전환 (L)

화면마다 3박자(repository 추출 -> 특성화 테스트 -> VM 추출)를 반복한다.
순서는 작은 화면에서 패턴을 확립한 뒤 큰 화면으로 간다.

1. LVE002_D01 상세 (201줄, dio 1건): 파일럿. 여기서 repository/VM/테스트의
   표준 형태를 확정한다.
2. LVE002_M01 내 목록: `LeaveRequestListProvider` 흡수. 전역 등록 제거.
3. LVE003_M01 결재 대기
4. LVE002_M02 전직원 목록
5. LVE002_M03 관리자 검색
6. LVE001_M01 휴가 신청 (1,136줄, 최대): `PublicHolidayProvider`를
   `public_holiday_repository`(메모리 캐시 포함)로 흡수. AUT001의 공휴일
   프리페치 호출도 함께 전환.

산출물: `leave_repository.dart`, `public_holiday_repository.dart`,
VM 6개, 특성화 테스트 6개, `leave_status_badge`/`date_range_dialog` 이동.

게이트: 화면별 3박자 커밋 규율, 특성화 테스트 green, leave 스모크 행 수행.

### 4단계: admin 기능 전환 (L)

1. ADM003 부서/팀: 기존 테스트가 있으므로 가장 먼저. `department_team_api`를
   `department_team_repository`로 이동/개명하고 static instance 교체를
   생성자 주입으로 전환. 기존 테스트 시나리오 무수정 통과가 게이트.
2. ADM004_M01 사번 조회, ADM004_D01 사원 상세
3. ADM001 관리팀 설정
4. ADM002 등록 관리 (`AuthProvider.adminAuthRegister` 호출을
   `signup_manage_repository`로 이동. AuthProvider 본체는 아직 유지)

산출물: `admin_employee_repository.dart`, `signup_manage_repository.dart`,
`department_team_repository.dart`, VM 5개, 특성화 테스트,
admin 전용 위젯 3개 이동.

### 5단계: dashboard 전환과 FCM 분리 (M)

- `DashboardProvider`를 `DSH001_M01_view_model.dart`와
  `core/services/fcm_service.dart`로 분리
- FCM 회귀 이력이 있는 지점(토큰 재전송, 토픽 중복 구독, 알림 거부 시
  로그인 불가)이므로, 분리 시 기존 조건 분기를 글자 그대로 옮기고
  스모크의 FCM 행을 실기기/브라우저에서 반드시 수행

### 6단계: employee 전환 (S)

- EMP001 내 정보: VM 추출, `email_autocomplete_field` 이동. 이메일 변경은
  auth_repository로 갈 예정이지만 이 시점에는 AuthProvider 호출 유지.

### 7단계: auth 최종 분해 (M, 파급 최대)

전 화면이 의존하므로 마지막에 수행한다.

- `AuthProvider` -> `features/auth/state/auth_session.dart`(세션 상태) +
  `features/auth/repositories/auth_repository.dart`(API 호출)로 분해
- AUT001/AUT002/AUT003 화면의 3박자 전환
- 앱 루트 Provider 등록을 AuthSession 하나로 축소
- 게이트: 전체 테스트 green + 스모크 체크리스트 전체 1회 수행
  (특히 자동 로그인, 세션 만료, 드로어 역할 분기)

### 8단계: 선별 UseCase 도입 (M)

- `submit_leave_request.dart`: LVE001 VM의 검증 로직(중복, 잔여연차,
  반차 조합)을 이동. 이동 전에 현재 동작 기준으로 단위 테스트를 먼저
  작성하고, 이동 후 같은 테스트가 통과해야 한다.
- `decide_signup.dart`: ADM002의 승인 규칙 동일 방식.
- Result/Failure를 repository 반환 타입에 일괄 적용하는 것도 이 단계에서.
  (그 전까지 repository는 기존과 동일하게 예외를 던져 동작 차이를 없앤다)

**실제 적용 기록 (2026-08-28)**

- `submit_leave_request.dart` 도입 완료. 중복/잔여연차 판정은 순수 정적
  함수로, 제출은 `Result<void>` 반환으로 구현했고 LVE001 VM이 위임한다.
- ADM002는 코드 확인 결과 별도 유스케이스로 뗄 승인 규칙이 없어(필드
  검증은 VM에 정리 완료), 관리자 역할 부여 규칙만
  `SignupManageViewModel.canAssignAdminRole` 정책 함수로 추출했다.
- Result/Failure의 repository 일괄 적용은 보류했다. 일부 VM(예: 내 목록
  조회)은 오류 시 예외가 그대로 전파되는 것이 현재 동작인데, Result로
  바꾸면 이 오류 경로의 동작이 달라져 이번 마이그레이션의 동작 보존
  원칙과 충돌한다. 오류 상태 표시를 화면별로 설계하는 후속 작업에서
  화면 단위로 전환한다. 신규 유스케이스(`submit_leave_request`)가 적용
  패턴의 예시다.

### 9단계: 마무리 (S)

- `lib/screens`, `lib/providers`, `lib/services`, `lib/models`,
  `lib/widgets`, `lib/theme`, `lib/config` 빈 디렉터리 제거
- `docs/screen-codes.md`의 위치 문구 갱신, 본 문서에 완료 기록
- 테스트 커버리지 확인 및 부족 화면 목록화

## 리스크와 대응

| 리스크 | 대응 |
|---|---|
| 대량 파일 이동과 활성 브랜치의 충돌 | 1~2단계는 대기 PR 정리 직후 하루 안에 완료 후 즉시 머지. 팀 사전 공지 |
| FCM 등 자동화 불가 영역의 회귀 | 조건 분기 원문 이동 원칙 + 실기기 수동 확인 항목 고정 |
| AuthProvider 분해의 파급 | 7단계로 최후 배치. 그 전까지 이름/동작 유지 |
| Result/Failure 도입 시 에러 메시지 변화 | 8단계로 분리. 그 전까지 repository는 기존 예외 방식 유지 |
| 특성화 테스트 작성 비용 초과 | 화면당 대표 시나리오 3~5개로 제한. 분기 조합은 VM 단위 테스트로 |
