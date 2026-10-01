import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

/// 사용자 등록 화면(AUT002_M01)의 ViewModel.
///
/// 사번과 비밀번호를 입력받아 서버에 사용 등록을 요청한다. (POST /api/auth/signup)
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

  /// 사용 등록. 성공하면 true를 돌려준다.
  ///
  /// 필수값과 비밀번호 확인 일치 여부는 서버 호출 전에 검사한다.
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
      // 오류 문자열에 DioException이 있으면 그 내용을, 아니면 일반 문구를 보여준다.
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
