import 'dart:convert';

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
  final DateTime? accessTokenExpiresAt;

  LoginResponse({
    required this.token,
    required this.employeeId,
    required this.name,
    required this.role,
    this.accessTokenExpiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    final claims = tryFromAccessToken(token);
    return LoginResponse(
      token: token,
      employeeId: (json['employeeId'] as num?)?.toInt() ?? claims?.employeeId,
      name: json['name']?.toString() ?? claims?.name,
      role: json['role']?.toString() ?? claims?.role,
      accessTokenExpiresAt: claims?.accessTokenExpiresAt,
    );
  }

  static LoginResponse? tryFromAccessToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map) return null;

      final employeeId = int.tryParse('${payload['sub'] ?? ''}');
      final expSeconds = (payload['exp'] as num?)?.toInt();

      return LoginResponse(
        token: token,
        employeeId: employeeId,
        name: payload['name']?.toString(),
        role: payload['role']?.toString(),
        accessTokenExpiresAt: expSeconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                expSeconds * 1000,
                isUtc: true,
              ),
      );
    } catch (_) {
      return null;
    }
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

class SyncFcmTokenRequest {
  final String fcmToken;
  final String deviceOs;

  SyncFcmTokenRequest({required this.fcmToken, required this.deviceOs});

  Map<String, dynamic> toJson() => {
        'fcmToken': fcmToken,
        'deviceOs': deviceOs,
      };
}

class AdminAuthRegisterRequest {
  final String employeeNumber;
  final String name;
  final String department;
  final String team;
  final String position;
  final String role;
  final String email;
  final String hireDate;

  AdminAuthRegisterRequest(
      {required this.employeeNumber,
      required this.name,
      required this.department,
      required this.team,
      required this.position,
      required this.role,
      required this.email,
      required this.hireDate});

  Map<String, dynamic> toJson() => {
        'employeeNumber': employeeNumber,
        'name': name,
        'department': department,
        'team': team,
        'position': position,
        'role': role,
        'email': email,
        'hireDate': hireDate,
      };
}
