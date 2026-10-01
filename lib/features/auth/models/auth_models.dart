import 'dart:convert';

/// 로그인 요청 본문. POST /api/auth/signin
class LoginRequest {
  final String employeeNumber;
  final String password;

  LoginRequest({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
        'employeeNumber': employeeNumber,
        'password': password,
      };
}

/// 로그인/토큰 갱신 응답. 액세스 토큰(JWT)과 그 안의 사용자 정보를 담는다.
///
/// 응답 본문에 값이 없으면 JWT payload(`sub`, `name`, `role`, `exp`)에서 보충한다.
/// 이 값은 화면 표시와 만료 판단용이며, 서명 검증은 하지 않으므로 권한 판단에 쓰면 안 된다.
class LoginResponse {
  final String token;
  final int? employeeId;
  final String? name;
  final String? role;

  /// 서버 refresh session의 안정 식별자. background logout이 이후 세션을
  /// 잘못 폐기하지 않도록 사용하며 refresh secret 자체는 아니다.
  final String? ssoSessionMarker;

  /// 액세스 토큰의 만료 시각(UTC). 토큰에서 읽지 못하면 null.
  final DateTime? accessTokenExpiresAt;

  LoginResponse({
    required this.token,
    required this.employeeId,
    required this.name,
    required this.role,
    this.ssoSessionMarker,
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
      ssoSessionMarker: json['ssoSessionMarker']?.toString(),
      accessTokenExpiresAt: claims?.accessTokenExpiresAt,
    );
  }

  /// 액세스 토큰(JWT)의 payload를 디코딩해 [LoginResponse]를 만든다. 서명은 검증하지 않는다.
  /// 형식이 올바르지 않거나 디코딩에 실패하면 null을 돌려준다.
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

/// 사용 등록 요청 본문. POST /api/auth/signup
class SignUpRequest {
  final String employeeNumber;
  final String password;

  SignUpRequest({required this.employeeNumber, required this.password});

  Map<String, dynamic> toJson() => {
        'employeeNumber': employeeNumber,
        'password': password,
      };
}

/// FCM 토큰 서버 등록 요청 본문. POST /api/admin/auth/sync-fcm-token
class SyncFcmTokenRequest {
  final String fcmToken;

  /// 기기 종류('Web', 'Android', 'iOS' 등).
  final String deviceOs;

  SyncFcmTokenRequest({required this.fcmToken, required this.deviceOs});

  Map<String, dynamic> toJson() => {
        'fcmToken': fcmToken,
        'deviceOs': deviceOs,
      };
}

/// 관리자가 등록 신청자를 승인하며 사원 정보를 확정할 때 보내는 요청 본문. (사용자 등록 관리 화면)
class AdminAuthRegisterRequest {
  final String employeeNumber;
  final String name;
  final String department;
  final String team;
  final String position;

  /// 부여할 역할 코드. `RoleType.code`('ADMIN' 또는 'EMPLOYEE').
  final String role;
  final String email;

  /// 입사일(yyyy-MM-dd).
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
