import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면(AUT001_M01)의 ViewModel.
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

  // 비밀번호 전용 안전 저장소
  final FlutterSecureStorage _secureStorage;

  final employeeNumberController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isRememberMe = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRememberMe => _isRememberMe;

  void setRememberMe(bool value) {
    _isRememberMe = value;
    notifyListeners();
  }

  void toggleRememberMe() {
    _isRememberMe = !_isRememberMe;
    notifyListeners();
  }

  // 로컬 저장소에서 계정 정보(사번 + 비밀번호) 불러오기
  Future<void> loadSavedAccountInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _isRememberMe = prefs.getBool('isRememberMe') ?? false;
    if (_isRememberMe) {
      // 일반 설정에서 사번 로드
      employeeNumberController.text =
          prefs.getString('savedEmployeeNumber') ?? '';
      // 암호화 공간에서 비밀번호 꺼내오기
      final savedPassword =
          await _secureStorage.read(key: 'savedPassword') ?? '';
      passwordController.text = savedPassword;
    }
    notifyListeners();
  }

  // 로그인 성공 시 계정 정보(사번 + 암호화 비밀번호) 저장 처리
  Future<void> _saveAccountInfoPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isRememberMe) {
      // 사번 일반 저장
      await prefs.setBool('isRememberMe', true);
      await prefs.setString(
          'savedEmployeeNumber', employeeNumberController.text.trim());
      // 비밀번호 안전하게 암호화 저장
      await _secureStorage.write(
          key: 'savedPassword', value: passwordController.text);
    } else {
      // 체크 해제 시 데이터 전부 일괄 소거
      await prefs.remove('isRememberMe');
      await prefs.remove('savedEmployeeNumber');
      await _secureStorage.delete(key: 'savedPassword'); // 암호 저장소 삭제
    }
  }

  /// 로그인. 성공하면 true를 돌려준다. (화면은 대시보드로 이동)
  Future<bool> login() async {
    if (employeeNumberController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _errorMessage = '사번과 비밀번호를 입력해주세요.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authSession.login(
        employeeNumberController.text.trim(),
        passwordController.text,
      );

      // 로그인이 최종 성공한 시점에 로컬 저장소 값 업데이트 수행 (사번+비번)
      await _saveAccountInfoPreference();

      try {
        await _holidayRepository.fetchPublicHolidays();
      } catch (_) {
        // 공휴일 조회 실패가 로그인 흐름을 막지 않도록 무시
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    employeeNumberController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
