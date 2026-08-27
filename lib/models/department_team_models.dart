// 부서 및 팀 관리 화면 전용 모델.
//
// 백엔드 부서/팀 CRUD API(feature/department-team-admin-api, PR #57) 응답에 대응한다.
// 상세 명세는 docs/api-spec-department-team.md 참고.

/// 대표이사 부서/팀 이름. 백엔드 DepartmentType 이 이름으로 식별하므로
/// 화면에서도 같은 이름으로 보호 대상(수정·삭제 불가)을 판별한다.
const String kCeoName = '대표이사';

/// 부서. GET /api/admin/departments 응답 한 건.
class Department {
  final int departmentId;
  final String departmentName;
  final bool enabled;

  Department({
    required this.departmentId,
    required this.departmentName,
    this.enabled = true,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        departmentId: json['departmentId'] as int,
        departmentName: json['departmentName'] ?? '',
        enabled: json['enabled'] ?? true,
      );

  /// 대표이사 부서는 백엔드가 이름 변경·삭제를 거부한다.
  bool get isProtected => departmentName == kCeoName;
}

/// 팀 담당자(PM). GET /api/admin/teams 응답의 managers 한 건.
class TeamManager {
  final int employeeId;
  final String employeeNumber;
  final String name;
  final String position;

  TeamManager({
    required this.employeeId,
    required this.employeeNumber,
    required this.name,
    required this.position,
  });

  factory TeamManager.fromJson(Map<String, dynamic> json) => TeamManager(
        employeeId: json['employeeId'] as int,
        employeeNumber: json['employeeNumber'] ?? '',
        name: json['name'] ?? '',
        position: json['position'] ?? '',
      );

  /// '홍길동 부장' 형태의 표시용 문자열.
  String get display => position.isEmpty ? name : '$name $position';
}

/// 팀. GET /api/admin/teams 응답 한 건.
class Team {
  final int teamId;
  final String teamName;
  final bool enabled;
  final int? departmentId;
  final String departmentName;
  final int? parentTeamId;
  final String? parentTeamName;
  final List<TeamManager> managers;

  Team({
    required this.teamId,
    required this.teamName,
    this.enabled = true,
    this.departmentId,
    this.departmentName = '',
    this.parentTeamId,
    this.parentTeamName,
    this.managers = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        teamId: json['teamId'] as int,
        teamName: json['teamName'] ?? '',
        enabled: json['enabled'] ?? true,
        departmentId: json['departmentId'],
        departmentName: json['departmentName'] ?? '',
        parentTeamId: json['parentTeamId'],
        parentTeamName: json['parentTeamName'],
        managers: (json['managers'] as List<dynamic>?)
                ?.map((e) => TeamManager.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// 루트 팀(대표이사)은 상위 팀이 자기 자신이다.
  bool get isRoot => parentTeamId != null && parentTeamId == teamId;
}

/// 부서 등록/수정 요청 body. (POST·PUT /api/admin/departments)
class DepartmentSaveRequest {
  final String departmentName;

  DepartmentSaveRequest({required this.departmentName});

  Map<String, dynamic> toJson() => {'departmentName': departmentName};
}

/// 팀 등록 요청 body. (POST /api/admin/teams)
///
/// parentTeamId 미지정 시 백엔드가 대표이사 팀을 상위 팀으로 설정한다.
class TeamCreateRequest {
  final String teamName;
  final int projectManagerId;
  final int departmentId;
  final int? parentTeamId;

  TeamCreateRequest({
    required this.teamName,
    required this.projectManagerId,
    required this.departmentId,
    this.parentTeamId,
  });

  Map<String, dynamic> toJson() => {
        'teamName': teamName,
        'projectManagerId': projectManagerId,
        'departmentId': departmentId,
        if (parentTeamId != null) 'parentTeamId': parentTeamId,
      };
}

/// 팀 수정 요청 body. (PUT /api/admin/teams/{teamId})
///
/// null 인 필드는 body 에서 제외되며 백엔드가 기존 값을 유지한다.
/// projectManagerId 지정 시 기존 담당자 전원이 이 사원 1명으로 교체되고,
/// departmentId 지정 시 소속 사원 전원의 부서도 함께 변경된다.
class TeamUpdateRequest {
  final String? teamName;
  final int? projectManagerId;
  final int? departmentId;
  final int? parentTeamId;

  TeamUpdateRequest({
    this.teamName,
    this.projectManagerId,
    this.departmentId,
    this.parentTeamId,
  });

  bool get isEmpty =>
      teamName == null &&
      projectManagerId == null &&
      departmentId == null &&
      parentTeamId == null;

  Map<String, dynamic> toJson() => {
        if (teamName != null) 'teamName': teamName,
        if (projectManagerId != null) 'projectManagerId': projectManagerId,
        if (departmentId != null) 'departmentId': departmentId,
        if (parentTeamId != null) 'parentTeamId': parentTeamId,
      };
}
