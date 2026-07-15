class Employee {
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String? hireDate;
  final String? role;
  final String email;

  Employee({
    required this.employeeNumber,
    required this.name,
    required this.position,
    required this.department,
    this.hireDate,
    this.role,
    required this.email,
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
  }) {
    return Employee(
      employeeNumber: employeeNumber ?? this.employeeNumber,
      name: name ?? this.name,
      position: position ?? this.position,
      department: department ?? this.department,
      hireDate: hireDate ?? this.hireDate,
      role: role ?? this.role,
      email: email ?? this.email,
    );
  }
}