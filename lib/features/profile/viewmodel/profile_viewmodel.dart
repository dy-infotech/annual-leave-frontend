import 'package:flutter/foundation.dart';
import '../model/dto/employee_dto.dart';
import '../model/api_client/profile_api_client.dart';

// ViewModel: "내 정보" 상태 관리. app_drawer, my_info_screen 등 여러 화면이
// 구독하므로 앱 전역(main.dart의 MultiProvider)에 등록해서 공유한다.
class ProfileViewModel extends ChangeNotifier {
  final ProfileApiClient _profileApiClient;
  ProfileViewModel(this._profileApiClient);

  EmployeeDto? _employeeInfo;
  bool _isLoading = false;

  bool _isChangingEmail = false;
  String? _emailError;

  bool _isChangingPassword = false;
  String? _passwordError;

  EmployeeDto? get employeeInfo => _employeeInfo;
  bool get isLoading => _isLoading;
  // 참고: 기존 코드는 로그인 시 응답받은 role로 isAdmin을 판단했는데,
  // 자동 로그인(tryAutoLogin) 시에는 그 값이 채워지지 않아 앱 재시작 후
  // isAdmin이 항상 false로 보이는 문제가 있었음. employeeInfo.role은
  // 로그인/자동로그인 모두 fetchMyInfo()로 채워지므로 여기서 기준으로 삼음.
  bool get isAdmin => _employeeInfo?.role == 'ADMIN';

  bool get isChangingEmail => _isChangingEmail;
  String? get emailError => _emailError;
  bool get isChangingPassword => _isChangingPassword;
  String? get passwordError => _passwordError;

  Future<void> fetchMyInfo() async {
    _isLoading = true;
    notifyListeners();
    try {
      _employeeInfo = await _profileApiClient.fetchMyInfo();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그아웃 시 View(app_drawer)가 AuthSessionViewModel.logout()과 함께 호출해서
  // 내 정보도 같이 비워준다.
  void clear() {
    _employeeInfo = null;
    notifyListeners();
  }

  Future<bool> changeEmail(String newEmail) async {
    if (newEmail.isEmpty) {
      _emailError = '이메일 정보를 입력해주세요.';
      notifyListeners();
      return false;
    }

    _isChangingEmail = true;
    _emailError = null;
    notifyListeners();

    try {
      await _profileApiClient.changeEmail(newEmail);
      _employeeInfo = _employeeInfo?.copyWith(email: newEmail);
      return true;
    } catch (e) {
      _emailError = '이메일 변경에 실패했습니다.';
      return false;
    } finally {
      _isChangingEmail = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    if (currentPassword.isEmpty || newPassword.isEmpty || newPasswordConfirm.isEmpty) {
      _passwordError = '모든 항목을 입력해주세요.';
      notifyListeners();
      return false;
    }
    if (newPassword != newPasswordConfirm) {
      _passwordError = '새 비밀번호가 일치하지 않습니다.';
      notifyListeners();
      return false;
    }
    if (newPassword == currentPassword) {
      _passwordError = '현재 비밀번호와 다른 비밀번호를 입력해주세요.';
      notifyListeners();
      return false;
    }

    _isChangingPassword = true;
    _passwordError = null;
    notifyListeners();

    try {
      await _profileApiClient.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _passwordError = '현재 비밀번호가 일치하지 않거나 변경에 실패했습니다.';
      return false;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }
}
