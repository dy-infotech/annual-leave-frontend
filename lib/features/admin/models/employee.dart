class Employee {
  /// employee PK. 팀 담당자(projectManagerId) 지정에 사용한다.
  /// 사원 목록 API 가 내려주지 않는 경우를 대비해 nullable 로 둔다.
  final int? employeeId;
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String team;
  final List<String>? teamList;
  final String? hireDate;
  final String? fireDate;
  final String? role;
  final String? email;
  final double currTotalLeaveDays;
  final double remainingLeaveDays;
  final String? approverNumber;
  final String? approverName;
  final String? approverPosition;
  final String? approverDepartment;
  final bool? isRegisted;
  final String? createdAt;

  Employee({
    this.employeeId,
    required this.employeeNumber,
    required this.name,
    required this.position,
    required this.department,
    required this.team,
    required this.teamList,
    this.hireDate,
    this.fireDate,
    this.role,
    this.email,
    required this.currTotalLeaveDays,
    required this.remainingLeaveDays,
    this.approverNumber,
    this.approverName,
    this.approverPosition,
    this.approverDepartment,
    required this.isRegisted,
    this.createdAt,
  });

  /// 최고 경영자 직급 여부.
  /// DB 표기가 '사장'(시드)과 '대표이사'(운영 데이터)로 혼재해 둘 다 인정한다.
  bool get isCeo => position == '사장' || position == '대표이사';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employeeId'],
      employeeNumber: json['employeeNumber'],
      name: json['name'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      team: json['team'] ?? '',
      teamList: (json['teamList'] as List<dynamic>?)
          ?.map((item) => item.toString())
          .toList(),
      hireDate: json['hireDate'],
      fireDate: json['fireDate'],
      role: json['role'],
      email: json['email'],
      currTotalLeaveDays:
          (json['currTotalLeaveDays'] as num?)?.toDouble() ?? 0.0,
      remainingLeaveDays:
          (json['remainingLeaveDays'] as num?)?.toDouble() ?? 0.0,
      approverNumber: json['approverNumber'] ?? '',
      approverName: json['approverName'] ?? '',
      approverPosition: json['approverPosition'] ?? '',
      approverDepartment: json['approverDepartment'] ?? '',
      isRegisted: json['isRegisted'] ?? false,
      createdAt: json['createdAt'],
    );
  }

  // copyWith 메서드 추가
  Employee copyWith(
      {String? employeeNumber,
      String? name,
      String? position,
      String? department,
      String? team,
      String? hireDate,
      String? fireDate,
      String? role,
      String? email,
      double? currTotalLeaveDays,
      double? remainingLeaveDays,
      String? approverNumber,
      String? approverName,
      String? approverPosition,
      String? approverDepartment,
      bool? isRegisted,
      String? createdAt}) {
    return Employee(
      employeeId: employeeId,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      position: position ?? this.position,
      department: department ?? this.department,
      team: team ?? this.team,
      teamList: teamList ?? this.teamList,
      hireDate: hireDate ?? this.hireDate,
      fireDate: fireDate ?? this.fireDate,
      role: role ?? this.role,
      email: email ?? this.email,
      currTotalLeaveDays: currTotalLeaveDays ?? this.currTotalLeaveDays,
      remainingLeaveDays: remainingLeaveDays ?? this.remainingLeaveDays,
      approverNumber: this.approverNumber,
      approverName: this.approverName,
      approverPosition: this.approverPosition,
      approverDepartment: this.approverDepartment,
      isRegisted: this.isRegisted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
