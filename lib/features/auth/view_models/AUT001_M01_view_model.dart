import 'package:annual_leave_frontend/features/auth/auth_preferences.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 로그인 입력과 세션 요청 상태를 관리한다
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required AuthSession authSession,
    PublicHolidayRepository? holidayRepository,
    FlutterSecureStorage? secureStorage,
  })  : _authSession = authSession,
        _holidayRepository = holidayRepository ?? PublicHolidayRepository(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AuthSession _authSession;
  final PublicHolidayRepository _holidayRepository;

  // 이전 버전 비밀번호 저장값을 정리할 때 사용한다
  final FlutterSecureStorage _secureStorage;

  final employeeNumberController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isRememberMe = false;
  bool _isAutoLoginEnabled = AuthPreferences.autoLoginDefault;
  bool _disposed = false;

  // 늦게 끝난 요청이 현재 화면 상태를 덮지 않도록 순번을 관리한다
  int _requestSeq = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRememberMe => _isRememberMe;
  bool get isAutoLoginEnabled => _isAutoLoginEnabled;

  void setRememberMe(bool value) {
    _isRememberMe = value;
    notifyListeners();
  }

  void toggleRememberMe() {
    _isRememberMe = !_isRememberMe;
    notifyListeners();
  }

  void setAutoLoginEnabled(bool value) {
    _isAutoLoginEnabled = value;
    notifyListeners();
  }

  void toggleAutoLogin() {
    _isAutoLoginEnabled = !_isAutoLoginEnabled;
    notifyListeners();
  }

  // 저장된 사번과 자동 로그인 설정을 불러온다
  Future<void> loadSavedAccountInfo() async {
    if (_disposed) return;
    final seq = ++_requestSeq;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || seq != _requestSeq) return;
    _isRememberMe =
        prefs.getBool(AuthPreferences.rememberEmployeeNumberKey) ?? false;
    _isAutoLoginEnabled =
        prefs.getBool(AuthPreferences.autoLoginKey) ??
            AuthPreferences.autoLoginDefault;
    if (_isRememberMe) {
      employeeNumberController.text =
          prefs.getString(AuthPreferences.savedEmployeeNumberKey) ?? '';
      // 이전 버전의 저장 비밀번호가 남아 있으면 삭제한다
      try {
        await _secureStorage.delete(key: 'savedPassword');
      } catch (e) {
        debugPrint('레거시 비밀번호 저장값 삭제 실패: $e');
      }
      if (_disposed || seq != _requestSeq) return;
    }
    if (!_disposed && seq == _requestSeq) notifyListeners();
  }

  // 로그인 후 계정 기억과 자동 로그인 설정을 저장한다
  Future<void> _saveAccountInfoPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isRememberMe) {
      await prefs.setBool(AuthPreferences.rememberEmployeeNumberKey, true);
      await prefs.setString(
        AuthPreferences.savedEmployeeNumberKey,
        employeeNumberController.text.trim(),
      );
    } else {
      await prefs.remove(AuthPreferences.rememberEmployeeNumberKey);
      await prefs.remove(AuthPreferences.savedEmployeeNumberKey);
    }

    await prefs.setBool(
      AuthPreferences.autoLoginKey,
      _isAutoLoginEnabled,
    );

    // 기존 비밀번호 저장값은 항상 제거한다
    await _secureStorage.delete(key: 'savedPassword');
  }

  // 로그인 후 부가 설정과 초기 데이터를 준비한다
  Future<bool> login() async {
    if (_disposed || _isLoading) return false;
    if (employeeNumberController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _errorMessage = '사번과 비밀번호를 입력해주세요.';
      notifyListeners();
      return false;
    }

    final seq = ++_requestSeq;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authSession.login(
        employeeNumberController.text.trim(),
        passwordController.text,
      );

      if (_disposed || seq != _requestSeq) return false;
      // 로그인 직후 세션 세대를 고정해 뒤늦은 화면 전환을 막는다
      final sessionGeneration = _authSession.captureGeneration();

      // 계정 설정 저장 실패는 로그인 결과와 분리한다
      try {
        await _saveAccountInfoPreference();
      } catch (e) {
        debugPrint('계정 저장 정보 갱신 실패: $e');
      }
      if (_disposed ||
          seq != _requestSeq ||
          !_authSession.isCurrentGeneration(sessionGeneration)) {
        return false;
      }

      // 로그인 후 공휴일 정보를 미리 불러온다
      try {
        await _holidayRepository.fetchPublicHolidays();
      } catch (_) {
        // 공휴일 조회 실패는 로그인 결과에 반영하지 않는다
      }

      // 초기 조회 중 세션이 바뀌면 이전 로그인 결과를 폐기한다
      if (_disposed ||
          seq != _requestSeq ||
          !_authSession.isCurrentGeneration(sessionGeneration)) {
        return false;
      }
      return true;
    } catch (e) {
      if (!_disposed && seq == _requestSeq) {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      if (!_disposed && seq == _requestSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSeq++;
    employeeNumberController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
