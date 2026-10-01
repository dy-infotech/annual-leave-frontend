import 'package:annual_leave_frontend/features/employee/repositories/employee_repository.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';

/// 내 정보 화면(EMP001_M01)의 ViewModel.
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

  /// 이메일 편집 시작. 기존 이메일을 입력란에 채운다.
  void startEditingEmail() {
    emailController.text = _authProvider.employeeInfo?.email ?? '';
    _isEditingEmail = true;
    notifyListeners();
  }

  /// 비밀번호 변경. 검증 통과 후 API 호출까지 성공하면 true를 돌려준다.
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

      // 여기부터는 서버의 비밀번호 변경과 refresh session 폐기가 이미 commit됐다.
      // 후속 로컬 logout 정리 실패를 성공한 mutation의 실패로 뒤집지 않는다.
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

  /// 이메일 변경. 성공 시 세션의 이메일도 갱신하고 편집 모드를 종료한다.
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
