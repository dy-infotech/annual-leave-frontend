class LoginRequest {
  final String employeeNumber;
  final String password;
  final String? fcmToken;
  final String? deviceOs;

  LoginRequest(
      {required this.employeeNumber,
      required this.password,
      this.fcmToken,
      this.deviceOs});

  Map<String, dynamic> toJson() => {
        'employeeNumber': employeeNumber,
        'password': password,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (deviceOs != null) 'deviceOs': deviceOs,
      };
}

class LoginResponse {
  final String token;
  final int? employeeId;
  final String? name;
  final String? role;

  LoginResponse({
    required this.token,
    required this.employeeId,
    required this.name,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      employeeId: json['employeeId'],
      name: json['name'],
      role: json['role'],
    );
  }

  bool get isAdmin => role == 'ADMIN';
}

class SignUpRequest {
  final String employeeNumber;
  final String password;

  SignUpRequest({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
        'employeeNumber': employeeNumber,
        'password': password,
      };
}

class AdminAuthRegisterRequest {
  final String name;
  final String department;
  final String team;
  final String position;
  final String role;
  final String email;
  final String hireDate;

  AdminAuthRegisterRequest(
      {required this.name,
      required this.department,
      required this.team,
      required this.position,
      required this.role,
      required this.email,
      required this.hireDate});

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
