import 'package:annual_leave_frontend/features/employee/repositories/employee_repository.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// 내 정보 수정과 요청 상태를 관리한다
class MyInfoViewModel extends ChangeNotifier {
  MyInfoViewModel({
    required AuthSession authProvider,
    EmployeeRepository? repository,
  })  : _authProvider = authProvider,
        _repository = repository ?? EmployeeRepository();

  final AuthSession _authProvider;
  final EmployeeRepository _repository;

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final newPasswordConfirmController = TextEditingController();
  final emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _emailErrorMessage;
  bool _isEditingEmail = false;
  bool _disposed = false;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get emailErrorMessage => _emailErrorMessage;
  bool get isEditingEmail => _isEditingEmail;

  // 현재 이메일을 입력값에 채우고 편집을 시작한다
  void startEditingEmail() {
    emailController.text = _authProvider.employeeInfo?.email ?? '';
    _isEditingEmail = true;
    notifyListeners();
  }

  // 입력값 확인 후 비밀번호 변경을 요청한다
  Future<bool> changePassword() async {
    if (_disposed || _isSubmitting) return false;
    if (currentPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        newPasswordConfirmController.text.isEmpty) {
      _errorMessage = '모든 항목을 입력해주세요.';
      notifyListeners();
      return false;
    }
    if (newPasswordController.text != newPasswordConfirmController.text) {
      _errorMessage = '새 비밀번호가 일치하지 않습니다.';
      notifyListeners();
      return false;
    }
    if (newPasswordController.text == currentPasswordController.text) {
      _errorMessage = '현재 비밀번호와 다른 비밀번호를 입력해주세요.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    final sessionGeneration = _authProvider.captureGeneration();
    notifyListeners();

    try {
      try {
        await _repository.changePassword(
          currentPassword: currentPasswordController.text,
          newPassword: newPasswordController.text,
        );
      } catch (e) {
        if (!_disposed) {
          _errorMessage = '현재 비밀번호가 일치하지 않거나 변경에 실패했습니다.';
        }
        return false;
      }

      // 서버 변경 성공 후 현재 로컬 세션을 정리한다
      if (!_disposed) {
        currentPasswordController.clear();
        newPasswordController.clear();
        newPasswordConfirmController.clear();
      }

      try {
        await _authProvider.logoutIfCurrent(sessionGeneration);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AUTH] 비밀번호 변경 후 로컬 로그아웃 정리 실패: $e');
        }
      }
      return true;
    } finally {
      _isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  // 이메일 변경 후 현재 세션 정보도 갱신한다
  Future<bool> changeEmail() async {
    if (_disposed || _isSubmitting) return false;
    if (emailController.text.isEmpty) {
      _emailErrorMessage = '이메일 정보를 입력해 주세요.';
      notifyListeners();
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(emailController.text)) {
      _emailErrorMessage = '올바른 이메일 형식이 아닙니다.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _emailErrorMessage = null;
    final sessionGeneration = _authProvider.captureGeneration();
    notifyListeners();

    try {
      final requestedEmail = emailController.text;
      await _repository.changeEmail(requestedEmail);
      if (_disposed) return true;

      _authProvider.updateEmailIfCurrent(sessionGeneration, requestedEmail);
      if (_disposed) return true;

      emailController.clear();
      _isEditingEmail = false;
      return true;
    } catch (e) {
      _emailErrorMessage = '이메일 변경에 실패했습니다.';
      return false;
    } finally {
      _isSubmitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    currentPasswordController.dispose();
    newPasswordController.dispose();
    newPasswordConfirmController.dispose();
    emailController.dispose();
    super.dispose();
  }
}
