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

  // 앱 시작 시 저장된 JWT가 있을 경우 로그인 상태로 간주
  Future<void> tryAutoLogin() async {
    final token = await _apiClient.getToken();
    if (token == null) {
      return;
    }

    try {
      _isLoggedIn = true;
      await fetchMyInfo();
      notifyListeners();
    } catch (e) {
      // 저장된 JWT가 만료됐거나 서버 응답 실패 시,
      // JWT를 지우고 로그인 안 된 상태로 되돌려서 다시 로그인하도록 유도
      await _apiClient.clearToken();
      _isLoggedIn = false;
      notifyListeners();
    }
  }

  Future<void> login(String employeeNumber, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(employeeNumber: employeeNumber, password: password).toJson(),
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
      data: SignUpRequest(employeeNumber: employeeNumber, password: password).toJson(),
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

  Future<void> fetchMyInfo() async {
    final response = await _apiClient.dio.get('/api/employees/me');
    _employeeInfo = Employee.fromJson(response.data);
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    notifyListeners();
  }
}
