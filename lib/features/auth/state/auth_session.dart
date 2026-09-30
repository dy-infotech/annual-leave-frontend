import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool _isLoggedIn = false;
  String? _role;
  String? _name;
  Employee? _employeeInfo;
  int _generation = 0;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _role == 'ADMIN';
  String? get name => _name;
  Employee? get employeeInfo => _employeeInfo;

  void _resetState({bool notify = true}) {
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    if (notify) notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;

  Future<void> fetchMyInfo() async {
    final generation = _generation;
    final info = await _repository.fetchMyInfo();
    if (!_isCurrent(generation)) return;

    // /me 성공 자체를 현재 세션의 유효성 확인으로 취급한다.
    // 로그아웃/새 로그인으로 generation이 바뀌면 늦은 응답은 위에서 폐기된다.
    _employeeInfo = info;
    _role = info.role;
    _name = info.name;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    final generation = ++_generation;
    final token = await _repository.getToken();
    if (!_isCurrent(generation)) return;
    if (token == null) {
      _resetState();
      return;
    }

    try {
      final info = await _repository.fetchMyInfo();
      if (!_isCurrent(generation)) return;

      _employeeInfo = info;
      _role = info.role;
      _name = info.name;
      _isLoggedIn = true;
      notifyListeners();
    } on DioException catch (e) {
      if (!_isCurrent(generation)) return;
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _repository.clearToken();
      }
      if (_isCurrent(generation)) _resetState();
    } catch (_) {
      if (!_isCurrent(generation)) return;
      await _repository.clearToken();
      if (_isCurrent(generation)) _resetState();
    }
  }

  Future<void> login(String employeeNumber, String password) async {
    final generation = ++_generation;
    _resetState(notify: false);

    try {
      final loginResponse =
          await _repository.signIn(employeeNumber, password);
      if (!_isCurrent(generation)) {
        throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
      }

      await _repository.saveToken(loginResponse.token);
      if (!_isCurrent(generation)) {
        throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
      }

      final info = await _repository.fetchMyInfo();
      if (!_isCurrent(generation)) {
        throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
      }

      _employeeInfo = info;
      _role = info.role;
      _name = info.name;
      _isLoggedIn = true;
      notifyListeners();
    } catch (_) {
      if (_isCurrent(generation)) {
        await _repository.clearToken();
        if (_isCurrent(generation)) _resetState();
      }
      rethrow;
    }
  }

  bool expireSession() {
    ++_generation;
    final wasLoggedIn = _isLoggedIn;
    _resetState();
    return wasLoggedIn;
  }

  Future<void> logout() async {
    ++_generation;
    _resetState();
    await _repository.clearToken();
  }

  Future<void> updateEmail(newEmail) async {
    final info = _employeeInfo;
    if (info == null) return;
    _employeeInfo = info.copyWith(email: newEmail);
    notifyListeners();
  }
}
