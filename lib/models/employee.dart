class Employee {
  final String employeeNo;
  final String name;
  final String position;
  final String department;
  final String? hireDate;
  final String? role;

  Employee({
    required this.employeeNo,
    required this.name,
    required this.position,
    required this.department,
    this.hireDate,
    this.role,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeNo: json['employeeNo'],
      name: json['name'],
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      hireDate: json['hireDate'],
      role: json['role'],
    );
  }
}