// 내 정보(프로필) DTO. app_drawer, my_info 화면 등 여러 화면이 공유해서 구독하는
// 데이터라 profile feature의 Model로 분리 (feature 전용이 아닌 "화면 여러 개가
// 참조하는 전역 상태"라는 성격은 ProfileViewModel 쪽에서 다룸).
class EmployeeDto {
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String? hireDate;
  final String? role;
  final String email;
  final double currTotalLeaveDays;
  final double remainingLeaveDays;
  final String? approverName;
  final String? approverPosition;
  final String? approverDepartment;

  EmployeeDto({
    required this.employeeNumber,
    required this.name,
    required this.position,
    required this.department,
    this.hireDate,
    this.role,
    required this.email,
    required this.currTotalLeaveDays,
    required this.remainingLeaveDays,
    this.approverName,
    this.approverPosition,
    this.approverDepartment,
  });

  factory EmployeeDto.fromJson(Map<String, dynamic> json) {
    return EmployeeDto(
      employeeNumber: json['employeeNumber'],
      name: json['name'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      hireDate: json['hireDate'],
      role: json['role'],
      email: json['email'],
      currTotalLeaveDays: (json['currTotalLeaveDays'] as num?)?.toDouble() ?? 0.0,
      remainingLeaveDays: (json['remainingLeaveDays'] as num?)?.toDouble() ?? 0.0,
      approverName: json['approverName'] ?? '',
      approverPosition: json['approverPosition'] ?? '',
      approverDepartment: json['approverDepartment'] ?? '',
    );
  }

  EmployeeDto copyWith({
    String? employeeNumber,
    String? name,
    String? position,
    String? department,
    String? hireDate,
    String? role,
    String? email,
    double? currTotalLeaveDays,
    double? remainingLeaveDays,
    String? approverName,
    String? approverPosition,
    String? approverDepartment,
  }) {
    return EmployeeDto(
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      position: position ?? this.position,
      department: department ?? this.department,
      hireDate: hireDate ?? this.hireDate,
      role: role ?? this.role,
      email: email ?? this.email,
      currTotalLeaveDays: currTotalLeaveDays ?? this.currTotalLeaveDays,
      remainingLeaveDays: remainingLeaveDays ?? this.remainingLeaveDays,
      approverName: this.approverName,
      approverPosition: this.approverPosition,
      approverDepartment: this.approverDepartment,
    );
  }
}
