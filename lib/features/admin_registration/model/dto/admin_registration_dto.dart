class AdminAuthRegisterRequestDto {
  final String name;
  final String department;
  final String team;
  final String position;
  final String role;
  final String email;
  final String hireDate;

  AdminAuthRegisterRequestDto({
    required this.name,
    required this.department,
    required this.team,
    required this.position,
    required this.role,
    required this.email,
    required this.hireDate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'department': department,
    'team': team,
    'position': position,
    'role': role,
    'email': email,
    'hireDate': hireDate,
  };
}

// 등록 폼의 드롭다운(부서/팀/직급) 옵션 데이터
class RegistrationCommonOptionsDto {
  final List<String> departments;
  final List<String> teams;
  final List<String> positions;

  RegistrationCommonOptionsDto({
    required this.departments,
    required this.teams,
    required this.positions,
  });

  factory RegistrationCommonOptionsDto.fromJson(Map<String, dynamic> json) {
    return RegistrationCommonOptionsDto(
      departments: List<String>.from(json['department']),
      teams: List<String>.from(json['team']),
      positions: List<String>.from(json['position']),
    );
  }
}
