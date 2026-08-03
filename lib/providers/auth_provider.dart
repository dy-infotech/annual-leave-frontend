import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../models/employee.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  bool _isLoggedIn = false;
  String? _role;
  String? _name;
  Employee? _employeeInfo;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _role == 'ADMIN';
  String? get name => _name;
  Employee? get employeeInfo => _employeeInfo;

  Future<void> fetchMyInfo() async {
    final response = await _apiClient.dio.get('/api/employees/me');
    _employeeInfo = Employee.fromJson(response.data);
    notifyListeners();
  }

  // 앱 시작 시 저장된 JWT가 있을 경우 로그인 상태로 간주
  Future<void> tryAutoLogin() async {
    final token = await _apiClient.getToken();

    if (token == null) {
      return;
    }

    try {
      _isLoggedIn = true;
      await fetchMyInfo();
    } catch (e) {
      // 저장된 JWT가 만료됐거나 서버 응답 실패 시, JWT를 지우고 로그인 안 된 상태로 되돌려서 다시 로그인하도록 유도
      await _apiClient.clearToken();
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> login(String employeeNumber, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
    final loginResponse = LoginResponse.fromJson(response.data);
    await _apiClient.saveToken(loginResponse.token);

    _isLoggedIn = true;
    _role = loginResponse.role;
    _name = loginResponse.name;

    await fetchMyInfo();

    notifyListeners();
  }

  Future<void> signUp(String employeeNumber, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequest(employeeNumber: employeeNumber, password: password)
          .toJson(),
    );
  }

  Future<void> adminAuthRegister(String name, String department, String team,
      String position, String role, String email, String hireDate) async {
    await _apiClient.dio.post(
      '/api/admin/auth/register',
      data: AdminAuthRegisterRequest(
              name: name,
              department: department,
              team: team,
              position: position,
              role: role,
              email: email,
              hireDate: hireDate)
          .toJson(),
    );
  }

  Future<void> sendPasswordResetEmail(
    String employeeNumber,
    String email,
  ) async {
    try {
      // 본인의 백엔드 '비밀번호 찾기(메일발송)' API 주소로 변경하세요.
      final response = await _apiClient.dio.post(
        '/api/auth/forgot-password',
        data: {'employeeNumber': employeeNumber, 'email': email},
      );

      if (response.statusCode != 200) {
        throw Exception('발송 실패');
      }

      notifyListeners(); // 필요한 경우 상태 업데이트
    } catch (e) {
      rethrow; // 에러를 화면단(ForgotPasswordScreen)으로 던져서 에러 메시지를 띄우게 합니다.
    }
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    notifyListeners();
  }

  Future<void> updateEmail(newEmail) async {
    // 기존 employeeInfo 객체에 이메일 갱신
    _employeeInfo = _employeeInfo!.copyWith(email: newEmail);
    notifyListeners();
  }

  // 💡 아이디 찾기 기능 추가
  Future<void> findId(String name, String email) async {
    try {
      // 본인의 백엔드 '아이디 찾기' API 주소로 변경하세요.
      final response = await _apiClient.dio.post(
        '/api/auth/find-id',
        data: {
          'name': name,
          'email': email,
        },
      );

      // 서버 응답에서 사번(아이디) 추출 (백엔드가 주는 key 이름에 맞게 수정하세요)
      // 예: { "employeeNumber": "EMP123456" } 형태로 온다고 가정한 코드입니다.
      // final String foundEmployeeNumber = response.data['employeeNumber'];

      // return foundEmployeeNumber;

      if (response.statusCode != 200) {
        throw Exception('발송 실패');
      }

      notifyListeners(); // 필요한 경우 상태 업데이트
    } catch (e) {
      // 에러를 화면단(FindAccountScreen)으로 던져서 에러 메시지를 띄우게 합니다.
      rethrow;
    }
  }
}
