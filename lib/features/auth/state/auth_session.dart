import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// 로그인 세션 상태. (기존 전역 인증 provider의 후신)
///
/// 앱 루트에 등록되는 유일한 전역 상태로, 로그인 여부와 내 정보를 보관한다.
/// API 호출은 AuthRepository에 위임한다.
class AuthSession extends ChangeNotifier {
  AuthSession({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool _isLoggedIn = false;
  String? _role;
  String? _name;
  Employee? _employeeInfo;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _role == 'ADMIN';
  String? get name => _name;
  Employee? get employeeInfo => _employeeInfo;

  Future<void> fetchMyInfo() async {
    final info = await _repository.fetchMyInfo();
    _employeeInfo = info;
    _role = info.role;
    _name = info.name;
    notifyListeners();
  }

  // 앱 시작 시 저장된 JWT가 있을 경우 로그인 상태로 간주
  Future<void> tryAutoLogin() async {
    final token = await _repository.getToken();
    if (token == null) return;

    try {
      final info = await _repository.fetchMyInfo();
      _employeeInfo = info;
      _role = info.role;
      _name = info.name;
      _isLoggedIn = true;
      notifyListeners();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _repository.clearToken();
      }
      _isLoggedIn = false;
      _role = null;
      _name = null;
      _employeeInfo = null;
      notifyListeners();
    } catch (_) {
      await _repository.clearToken();
      _isLoggedIn = false;
      _role = null;
      _name = null;
      _employeeInfo = null;
      notifyListeners();
    }
  }

  Future<void> login(String employeeNumber, String password) async {
    try {
      final loginResponse =
          await _repository.signIn(employeeNumber, password);
      final info = await _repository.fetchMyInfo();

      _employeeInfo = info;
      _role = loginResponse.role;
      _name = loginResponse.name;
      _isLoggedIn = true;
      notifyListeners();
    } catch (_) {
      // signIn 성공 뒤 /me가 실패해도 저장 JWT/메모리 세션이 남지 않게 롤백한다.
      await _repository.clearToken();
      _isLoggedIn = false;
      _role = null;
      _name = null;
      _employeeInfo = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repository.clearToken();
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
}
