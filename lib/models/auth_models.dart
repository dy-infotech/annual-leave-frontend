class LoginRequest {
  final String employeeNumber;
  final String password;

  LoginRequest({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
    'employeeNumber': employeeNumber,
    'password': password,
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
