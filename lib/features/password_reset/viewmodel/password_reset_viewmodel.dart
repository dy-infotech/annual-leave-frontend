import 'package:flutter/foundation.dart';
import '../model/api_client/password_reset_api_client.dart';

class PasswordResetViewModel extends ChangeNotifier {
  final PasswordResetApiClient _passwordResetApiClient;
  PasswordResetViewModel(this._passwordResetApiClient);

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _sentSuccessfully = false;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get sentSuccessfully => _sentSuccessfully;

  Future<bool> sendResetEmail({
    required String employeeNumber,
    required String email,
  }) async {
    if (employeeNumber.isEmpty || email.isEmpty) {
      _errorMessage = '사번과 이메일을 모두 입력해 주세요.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _passwordResetApiClient.sendResetEmail(employeeNumber, email);
      _sentSuccessfully = true;
      return true;
    } catch (e) {
      _errorMessage = '등록된 정보가 일치하지 않거나 발송에 실패했습니다.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
