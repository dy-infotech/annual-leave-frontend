// 부서 및 팀 관리 화면 전용 모델.
//
// 백엔드에 부서/팀 CRUD API가 아직 없어(2026-08 기준) 응답 형태가 확정되지 않았다.
// 그래서 fromJson 은 키 이름을 여러 후보로 받아들이고, id 계열은 전부 nullable 로 둔다.
// 서버 스펙이 확정되면 후보 키와 nullable 을 정리할 것.

/// 부서. 현재 백엔드에서는 DepartmentType enum 이라 id 가 없다.
class Department {
  final int? departmentId;
  final String departmentName;

  /// 목록에 '팀 N개' 를 표기하기 위한 값. 서버가 안 내려주면 null.
  final int? teamCount;

  Department({
    this.departmentId,
    required this.departmentName,
    this.teamCount,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        departmentId: json['departmentId'],
        departmentName:
            json['departmentName'] ?? json['department'] ?? json['name'] ?? '',
        teamCount: json['teamCount'],
      );

  /// 이름만 내려주는 폴백 경로(/api/admin/auth/common)용.
  factory Department.fromName(String name) => Department(departmentName: name);

  /// id 가 없는 폴백 데이터는 수정할 수 없다.
  bool get isEditable => departmentId != null;
}

/// 팀 관리자. 백엔드 team.project_manager_id 에 대응한다.
class TeamManager {
  final String employeeNumber;
  final String name;
  final String position;

  TeamManager({
    required this.employeeNumber,
    required this.name,
    required this.position,
  });

  factory TeamManager.fromJson(Map<String, dynamic> json) => TeamManager(
        employeeNumber: json['employeeNumber'] ?? '',
        name: json['name'] ?? '',
        position: json['position'] ?? '',
      );

  /// '홍길동 부장' 형태의 표시용 문자열.
  String get display =>
      position.isEmpty ? name : '$name $position';
}

/// 팀. 백엔드 team 테이블(seq, team, project_manager_id, parent_team)에 대응한다.
///
/// 주의: 백엔드는 팀 하나에 관리자가 여러 명이면 같은 team 이름으로 행을 여러 개 만든다.
/// 화면에서는 팀 이름 기준으로 묶어 managers 리스트로 다룬다.
class Team {
  final int? teamId;
  final String teamName;

  /// 상위 팀. 백엔드 parent_team 컬럼은 NOT NULL 이다.
  final String? parentTeam;

  /// 최소 1명. 비어 있는 팀은 백엔드 제약상 존재할 수 없지만 방어적으로 빈 리스트를 허용한다.
  final List<TeamManager> managers;

  Team({
    this.teamId,
    required this.teamName,
    this.parentTeam,
    required this.managers,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        teamId: json['teamId'] ?? json['seq'],
        teamName: json['teamName'] ?? json['team'] ?? json['name'] ?? '',
        parentTeam: json['parentTeam'],
        managers: (json['managers'] as List<dynamic>?)
                ?.map((e) => TeamManager.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// 이름만 내려주는 폴백 경로(/api/admin/auth/common)용.
  factory Team.fromName(String name) => Team(teamName: name, managers: const []);

  /// id 가 없는 폴백 데이터는 수정할 수 없다.
  bool get isEditable => teamId != null;
}

/// 부서 등록/수정 요청 body.
class DepartmentSaveRequest {
  final String departmentName;

  DepartmentSaveRequest({required this.departmentName});

  Map<String, dynamic> toJson() => {
        'departmentName': departmentName,
      };
}

/// 팀 등록/수정 요청 body.
///
/// managerEmployeeNumbers 는 최소 1건이어야 한다(화면에서 검증).
class TeamSaveRequest {
  final String teamName;
  final String? parentTeam;
  final List<String> managerEmployeeNumbers;

  TeamSaveRequest({
    required this.teamName,
    this.parentTeam,
    required this.managerEmployeeNumbers,
  });

  Map<String, dynamic> toJson() => {
        'teamName': teamName,
        'parentTeam': parentTeam,
        'managerEmployeeNumbers': managerEmployeeNumbers,
      };
}
