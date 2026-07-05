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

  Future<void> login(String employeeNo, String password) async {
    final response = await _apiClient.dio.post(
      '/api/auth/signin',
      data: LoginRequest(employeeNo: employeeNo, password: password).toJson(),
    );

    final loginResponse = LoginResponse.fromJson(response.data);
    await _apiClient.saveToken(loginResponse.token);

    _isLoggedIn = true;
    _role = loginResponse.role;
    _name = loginResponse.name;

    await fetchMyInfo();
    notifyListeners();
  }

  Future<void> signUp(String employeeNo, String password) async {
    await _apiClient.dio.post(
      '/api/auth/signup',
      data: SignUpRequest(employeeNo: employeeNo, password: password).toJson(),
    );
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