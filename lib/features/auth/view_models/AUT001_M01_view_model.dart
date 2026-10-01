import 'package:annual_leave_frontend/features/auth/auth_preferences.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면(AUT001_M01)의 ViewModel.
///
/// 입력 검증, 로그인 요청, 사번 저장/자동 로그인 환경설정 저장을 담당한다.
/// 비밀번호는 저장하지 않으며 실제 인증과 세션 상태는 [AuthSession]에 위임한다.
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
  bool _isAutoLoginEnabled = AuthPreferences.autoLoginDefault;
  bool _disposed = false;

  /// 요청 순번. 저장 정보 불러오기나 로그인이 끝나기 전에 화면이 닫히거나 새 요청이 시작되면
  /// 늦게 도착한 결과가 상태를 덮어쓰지 않도록 비교하는 데 쓴다.
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

  // 로컬 저장소에서 저장된 사번만 불러온다. 비밀번호는 refresh session으로 대체하고 장기 저장하지 않는다.
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
      // 이전 버전이 저장해 둔 원문 비밀번호는 마이그레이션 시 즉시 폐기한다.
      try {
        await _secureStorage.delete(key: 'savedPassword');
      } catch (e) {
        debugPrint('레거시 비밀번호 저장값 삭제 실패: $e');
      }
      if (_disposed || seq != _requestSeq) return;
    }
    if (!_disposed && seq == _requestSeq) notifyListeners();
  }

  // 로그인 성공 시 사번 저장 여부와 다음 실행의 자동 로그인 여부를 반영한다.
  // 자동 로그인은 refresh session을 재사용할지 여부만 저장하며 비밀번호는 저장하지 않는다.
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

    // 어느 경로에서도 원문 비밀번호를 장기 저장하지 않는다.
    await _secureStorage.delete(key: 'savedPassword');
  }

  /// 로그인. 성공하면 true를 돌려준다. (화면은 대시보드로 이동)
  ///
  /// 실패하면 false를 돌려주고 [errorMessage]에 사유를 담는다.
  /// 로그인 이후의 계정 저장과 공휴일 미리 불러오기는 부가 작업이라 실패해도 로그인 결과에 영향을 주지 않는다.
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

      // 계정 기억하기는 로그인 자체와 분리된 부가 기능이다.
      // 저장소 실패가 이미 확정된 인증 세션까지 실패로 보이게 만들지 않는다.
      try {
        await _saveAccountInfoPreference();
      } catch (e) {
        debugPrint('계정 저장 정보 갱신 실패: $e');
      }

      // 휴가 신청 화면에서 바로 쓸 수 있도록 공휴일을 미리 조회해 캐시한다.
      try {
        await _holidayRepository.fetchPublicHolidays();
      } catch (_) {
        // 공휴일 조회 실패가 로그인 흐름을 막지 않도록 무시
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
