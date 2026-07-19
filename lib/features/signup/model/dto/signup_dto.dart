class SignUpRequestDto {
  final String employeeNumber;
  final String password;

  SignUpRequestDto({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
    'employeeNumber': employeeNumber,
    'password': password,
  };
}
