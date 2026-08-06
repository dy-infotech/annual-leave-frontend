class Employee {
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String? team;
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

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
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
