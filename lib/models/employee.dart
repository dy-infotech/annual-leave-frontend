class Employee {
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String? hireDate;
  final String? role;
  final String email;
  final double currTotalLeaveDays;
  final double remainingLeaveDays;
  final String? approverNumber;
  final String? approverName;
  final String? approverPosition;
  final String? approverDepartment;


  Employee({
    required this.employeeNumber,
    required this.name,
    required this.position,
    required this.department,
    this.hireDate,
    this.role,
    required this.email,
    required this.currTotalLeaveDays,
    required this.remainingLeaveDays,
    this.approverNumber,
    this.approverName,
    this.approverPosition,
    this.approverDepartment,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeNumber: json['employeeNumber'],
      name: json['name'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      hireDate: json['hireDate'],
      role: json['role'],
      email: json['email'],
      currTotalLeaveDays: (json['currTotalLeaveDays'] as num?)?.toDouble() ?? 0.0,
      remainingLeaveDays: (json['remainingLeaveDays'] as num?)?.toDouble() ?? 0.0,
      approverNumber: json['approverNumber'] ?? '',
      approverName: json['approverName'] ?? '',
      approverPosition: json['approverPosition'] ?? '',
      approverDepartment: json['approverDepartment'] ?? '',
    );
  }

  // copyWith 메서드 추가
  Employee copyWith({
    String? employeeNumber,
    String? name,
    String? position,
    String? department,
    String? hireDate,
    String? role,
    String? email,
    double? currTotalLeaveDays,
    double? remainingLeaveDays,
    String? approverNumber,
    String? approverName,
    String? approverPosition,
    String? approverDepartment,
  }) {
    return Employee(
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      position: position ?? this.position,
      department: department ?? this.department,
      hireDate: hireDate ?? this.hireDate,
      role: role ?? this.role,
      email: email ?? this.email,
      currTotalLeaveDays: currTotalLeaveDays ?? this.currTotalLeaveDays,
      remainingLeaveDays: remainingLeaveDays ?? this.remainingLeaveDays,
      approverNumber: this.approverNumber,
      approverName: this.approverName,
      approverPosition: this.approverPosition,
      approverDepartment: this.approverDepartment,
    );
  }
}
