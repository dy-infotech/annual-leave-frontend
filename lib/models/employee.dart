class Employee {
  final String employeeNumber;
  final String name;
  final String position;
  final String department;
  final String? hireDate;
  final String? role;

  Employee({
    required this.employeeNumber,
    required this.name,
    required this.position,
    required this.department,
    this.hireDate,
    this.role,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeNumber: json['employeeNumber'],
      name: json['name'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      hireDate: json['hireDate'],
      role: json['role'],
    );
  }
}