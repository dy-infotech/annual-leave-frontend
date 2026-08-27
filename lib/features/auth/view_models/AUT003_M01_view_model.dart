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

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 탭 전환 시 에러 메시지 초기화.
  void clearInputs() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 아이디 찾기 메일 발송. 성공하면 true를 돌려준다.
  Future<bool> findId() async {
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
      notifyListeners();
    }
  }

  /// 비밀번호 재설정 메일 발송. 성공하면 true를 돌려준다.
  Future<bool> sendPasswordResetEmail() async {
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
      return true;
    } catch (e) {
      print("비밀번호 찾기 에러 발생: $e");
      _errorMessage = '등록된 정보가 일치하지 않거나 발송에 실패했습니다.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailForIdController.dispose();
    employeeNoController.dispose();
    emailForPwController.dispose();
    super.dispose();
  }
}
