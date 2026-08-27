# 화면 코드 체계

화면 파일명은 `<기능코드><기능번호>_<유형><순번>.dart` 형식을 따른다.

- 기능코드: `AUT`(auth) · `LVE`(leave) · `EMP`(employee) · `ADM`(admin) · `DSH`(dashboard)
- 기능번호(3자리): 기능 단위 그룹 번호
- 유형: `M`(메인) · `T`(탭) · `D`(디테일) · `P`(팝업)

추후 MVVM 적용 시 `lib/features/<기능코드>/` 하위로 이동할 예정이며, 현재는 `lib/screens/`에 위치한다.

## 화면 목록

| 코드 | 화면명 | 클래스 | 기존 파일명 | 라우트 |
|---|---|---|---|---|
| AUT001_M01 | 로그인 | `LoginScreen` | login_screen.dart | `/login` |
| AUT002_M01 | 사용자 등록(회원가입) | `SignupScreen` | signup_screen.dart | `/signup` |
| AUT003_M01 | 계정 찾기 (아이디/비밀번호 탭) | `FindAccountScreen` | forgotPasswordScreen.dart | `/forgot-password` |
| DSH001_M01 | 대시보드 | `DashboardScreen` | dashboard_screen.dart | `/dashboard` |
| LVE001_M01 | 휴가 신청 | `LeaveRequestScreen` | leave_request_screen.dart | `/leave-request` |
| LVE002_M01 | 내 휴가 신청 목록 | `MyLeaveRequestsScreen` | my_leave_requests_screen.dart | (미사용) |
| LVE002_M02 | 전직원 휴가 신청 목록 | `AllLeaveRequestsScreen` | all_leave_requests_screen.dart | `/all-leave-requests` |
| LVE002_M03 | 관리자 휴가 검색 | `AdminSearchLeaveRequestsScreen` | admin_search_leave_requests_screen.dart | - |
| LVE002_D01 | 휴가 신청 상세 | `LeaveRequestDetailScreen` | leave_request_detail_screen.dart | - |
| LVE003_M01 | 결재 대기 목록 | `PendingApprovalScreen` | pending_approval_screen.dart | `/pending-approval` |
| EMP001_M01 | 내 정보 | `MyInfoScreen` | my_info_screen.dart | `/my-info` |
| EMP002_M01 | 사원 사번 조회 | `SearchEmployeeNumberScreen` | search_employee_number_screen.dart | `/search_employee_number_screen` |
| EMP002_D01 | 사원 상세 | `EmployeeDetailScreen` | employee_detail_screen.dart | - |
| ADM001_M01 | 관리자별 관리팀 설정 | `AdminSettingsScreen` | admin-settings.dart | `/admin-settings` |
| ADM002_M01 | 사용자 등록 관리 | `SignupManageScreen` | signup_manage_screen.dart | `/signup_manage_screen` |
| ADM003_M01 | 부서 및 팀 관리 (부서/팀 탭) | `DepartmentTeamManageScreen` | department_team_manage_screen.dart | `/department-team-manage` |

## 그룹 구성 기준

- **LVE002 (휴가 목록 조회)**: 내 휴가(M01)·전직원(M02)·관리자 검색(M03) 목록 화면이 공용 상세 화면(D01)을 공유하므로 하나의 그룹으로 묶었다. 결재 대기(LVE003_M01)도 LVE002_D01로 진입한다.
- **EMP002 (사번 조회)**: 사번 조회(M01)에서 사원 상세(D01)로 진입한다.
- AUT003_M01(아이디/비밀번호 찾기)과 ADM003_M01(부서/팀)의 탭은 파일 분리 없이 화면 내부 위젯으로 구현되어 있어 별도 `T` 코드를 부여하지 않았다. 추후 탭을 파일로 분리하면 `AUT003_T01`처럼 부여한다.
- 다이얼로그류(`lib/widgets/`의 date_input_dialog 등)는 화면이 아닌 공용 위젯이므로 코드화 대상에서 제외했다. 특정 화면 전용 팝업을 파일로 분리하는 시점에 `P` 코드를 부여한다.
