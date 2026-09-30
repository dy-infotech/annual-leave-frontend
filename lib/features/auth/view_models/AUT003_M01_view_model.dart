import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

/// 계정 찾기 화면(AUT003_M01)의 ViewModel.
class FindAccountViewModel extends ChangeNotifier {
  FindAccountViewModel({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  // 공통 및 아이디 찾기용 컨트롤러
  final nameController = TextEditingController();
  final emailForIdController = TextEditingController();

  // 비밀번호 찾기용 컨트롤러
  final employeeNoController = TextEditingController();
  final emailForPwController = TextEditingController();
  final resetTokenController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _resetRequested = false;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get resetRequested => _resetRequested;

  /// 탭 전환 시 에러 메시지 초기화.
  void clearInputs() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 아이디 찾기 메일 발송. 성공하면 true를 돌려준다.
  Future<bool> findId() async {
    if (_disposed || _isLoading) return false;
    if (nameController.text.isEmpty || emailForIdController.text.isEmpty) {
      _errorMessage = '성함과 이메일을 모두 입력해 주세요.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.findId(
        nameController.text.trim(),
        emailForIdController.text.trim(),
      );
      return true;
    } catch (e) {
      print("아이디 찾기 에러 발생: $e");
      _errorMessage = '등록된 정보가 일치하지 않습니다.';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 비밀번호 재설정 메일 발송. 성공하면 true를 돌려준다.
  Future<bool> sendPasswordResetEmail() async {
    if (_disposed || _isLoading) return false;
    if (employeeNoController.text.isEmpty ||
        emailForPwController.text.isEmpty) {
      _errorMessage = '사번과 이메일을 모두 입력해 주세요.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendPasswordResetEmail(
        employeeNoController.text.trim(),
        emailForPwController.text.trim(),
      );
      _resetRequested = true;
      return true;
    } catch (e) {
      print("비밀번호 찾기 에러 발생: $e");
      _errorMessage = '등록된 정보가 일치하지 않거나 발송에 실패했습니다.';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> confirmPasswordReset() async {
    if (_disposed || _isLoading) return false;
    if (resetTokenController.text.trim().isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _errorMessage = '재설정 토큰과 새 비밀번호를 모두 입력해 주세요.';
      notifyListeners();
      return false;
    }
    if (newPasswordController.text != confirmPasswordController.text) {
      _errorMessage = '새 비밀번호 확인이 일치하지 않습니다.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.resetPassword(
        resetTokenController.text.trim(),
        newPasswordController.text,
      );
      return true;
    } catch (_) {
      _errorMessage = '재설정 토큰이 유효하지 않거나 만료되었습니다.';
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    nameController.dispose();
    emailForIdController.dispose();
    employeeNoController.dispose();
    emailForPwController.dispose();
    resetTokenController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
