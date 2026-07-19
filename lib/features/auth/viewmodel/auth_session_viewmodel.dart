import 'package:flutter/foundation.dart';
import '../model/api_client/auth_api_client.dart';

// ViewModel: "로그인 세션" 상태만 관리. View를 참조하지 않음(단방향 의존).
// 주의: 로그인/자동로그인 성공 후 "내 정보(EmployeeDto)" 조회는
// features/profile의 ProfileViewModel 책임이라 여기서 다루지 않는다.
// -> View(SplashScreen, LoginScreen)가 이 둘을 순서대로 호출해 조합한다.
// (기존 코드에서도 로그인 성공 후 PublicHolidayViewModel을 화면에서 이어 호출하던
//  방식과 동일한 패턴이라, 이 프로젝트의 기존 관례를 그대로 따른 것)
class AuthSessionViewModel extends ChangeNotifier {
  final AuthApiClient _authApiClient;
  AuthSessionViewModel(this._authApiClient);

  bool _isLoggedIn = false;
  String? _name;

  bool get isLoggedIn => _isLoggedIn;
  String? get name => _name;

  // 앱 시작 시 저장된 JWT가 있는지만 확인 (서버 검증은 View가 profile 조회로 이어서 수행)
  Future<void> tryAutoLogin() async {
    final token = await _authApiClient.getStoredToken();
    _isLoggedIn = token != null;
    notifyListeners();
  }

  Future<void> login(String employeeNumber, String password) async {
    final loginResponse = await _authApiClient.login(employeeNumber, password);
    await _authApiClient.saveSession(loginResponse.token);

    _isLoggedIn = true;
    _name = loginResponse.name;
    notifyListeners();
  }

  // 자동 로그인 시도 후 서버 검증(프로필 조회)에 실패했을 때, View가 호출해서
  // 세션을 되돌리기 위한 메서드. (JWT 만료 등)
  Future<void> invalidateSession() async {
    await _authApiClient.clearSession();
    _isLoggedIn = false;
    _name = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authApiClient.clearSession();
    _isLoggedIn = false;
    _name = null;
    notifyListeners();
  }
}
