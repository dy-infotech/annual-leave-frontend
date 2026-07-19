// 로그인 요청/응답 DTO. 세션(로그인 상태) 도메인에서만 쓰이는 데이터 형태.
class LoginRequestDto {
  final String employeeNumber;
  final String password;

  LoginRequestDto({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
    'employeeNumber': employeeNumber,
    'password': password,
  };
}

class LoginResponseDto {
  final String token;
  final int? employeeId;
  final String? name;
  final String? role;

  LoginResponseDto({
    required this.token,
    required this.employeeId,
    required this.name,
    required this.role,
  });

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    return LoginResponseDto(
      token: json['token'],
      employeeId: json['employeeId'],
      name: json['name'],
      role: json['role'],
    );
  }
}
