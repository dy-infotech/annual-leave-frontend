import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

// 사용자 등록 입력과 요청 상태를 관리한다
class SignupViewModel extends ChangeNotifier {
  SignupViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  final employeeNumberController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // 입력값을 확인한 뒤 사용자 등록을 요청한다
  Future<bool> signUp() async {
    if (_disposed || _isLoading) return false;
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
      // 서버 오류가 있으면 화면에 전달할 메시지로 정리한다
      _errorMessage = e.toString().contains('DioException')
          ? e.toString()
          : '사용 등록에 실패했습니다.';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    employeeNumberController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }
}
