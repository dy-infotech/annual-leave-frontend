import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

/// 사용자 등록 화면(AUT002_M01)의 ViewModel.
class SignupViewModel extends ChangeNotifier {
  SignupViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  final employeeNumberController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 사용 등록. 성공하면 true를 돌려준다.
  Future<bool> signUp() async {
    if (employeeNumberController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _errorMessage = '사번과 비밀번호를 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (passwordController.text != passwordConfirmController.text) {
      _errorMessage = '비밀번호가 일치하지 않습니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.signUp(
        employeeNumberController.text.trim(),
        passwordController.text,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().contains('DioException')
          ? e.toString()
          : '사용 등록에 실패했습니다.';
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
    passwordConfirmController.dispose();
    super.dispose();
  }
}
