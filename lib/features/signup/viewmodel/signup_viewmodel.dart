import 'package:flutter/foundation.dart';
import '../model/api_client/signup_api_client.dart';

// 이 화면에서만 쓰이는 상태라 main.dart 전역이 아니라, signup_screen을 감싸는
// 지점에서 화면 전용(scoped)으로 생성한다.
class SignupViewModel extends ChangeNotifier {
  final SignupApiClient _signupApiClient;
  SignupViewModel(this._signupApiClient);

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<bool> signUp({
    required String employeeNumber,
    required String password,
    required String passwordConfirm,
  }) async {
    if (employeeNumber.isEmpty || password.isEmpty) {
      _errorMessage = '사번과 비밀번호를 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (password != passwordConfirm) {
      _errorMessage = '비밀번호가 일치하지 않습니다.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _signupApiClient.signUp(employeeNumber, password);
      return true;
    } catch (e) {
      _errorMessage = '사용 등록에 실패했습니다.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
