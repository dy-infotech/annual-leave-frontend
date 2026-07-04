class LoginRequest {
  final String employeeNo;
  final String password;

  LoginRequest({required this.employeeNo, required this.password});

  Map<String, dynamic> toJson() => {
        'employeeNo': employeeNo,
        'password': password,
      };
}

class LoginResponse {
  final String token;
  final int employeeId;
  final String name;
  final String role;

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
  final String employeeNo;
  final String password;

  SignUpRequest({required this.employeeNo, required this.password});

  Map<String, dynamic> toJson() => {
        'employeeNo': employeeNo,
        'password': password,
      };
}
