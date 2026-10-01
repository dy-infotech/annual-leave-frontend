import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

// 로그인 사용자 정보와 세션 전환 상태를 관리한다
class AuthSession extends ChangeNotifier {
  AuthSession({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  bool _isLoggedIn = false;
  String? _role;
  String? _name;
  Employee? _employeeInfo;
  int _generation = 0;

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _role == 'ADMIN';
  String? get name => _name;
  Employee? get employeeInfo => _employeeInfo;

  // 로그인 관련 화면 상태를 초기화한다
  void _resetState({bool notify = true}) {
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    if (notify) notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;

  // 비동기 작업 시작 시 현재 세션 세대를 보관한다
  int captureGeneration() => _generation;

  bool isCurrentGeneration(int generation) => _isCurrent(generation);

  // 내 정보를 다시 조회해 현재 세션 상태를 갱신한다
  Future<void> fetchMyInfo() async {
    final generation = _generation;
    final info = await _repository.fetchMyInfo();
    if (!_isCurrent(generation)) return;

    // 조회가 끝날 때까지 같은 세션이면 결과를 반영한다
    _employeeInfo = info;
    _role = info.role;
    _name = info.name;
    _isLoggedIn = true;
    notifyListeners();
  }

  // 앱 시작 시 자동 로그인 설정에 따라 세션을 복원한다
  Future<void> tryAutoLogin({bool enabled = true}) async {
    final generation = ++_generation;

    if (!enabled) {
      await _repository.clearToken();
      if (_isCurrent(generation)) _resetState();
      return;
    }

    try {
      final token = await _repository.getToken();
      if (!_isCurrent(generation)) return;
      if (token == null) {
        _resetState();
        return;
      }

      final info = await _repository.fetchMyInfo();
      if (!_isCurrent(generation)) return;

      _employeeInfo = info;
      _role = info.role;
      _name = info.name;
      _isLoggedIn = true;
      notifyListeners();
    } catch (_) {
      if (!_isCurrent(generation)) return;
      await _repository.clearToken();
      if (_isCurrent(generation)) _resetState();
    }
  }

  // 서버 로그인과 내 정보 조회가 끝나면 세션을 확정한다
  Future<void> login(String employeeNumber, String password) async {
    final generation = ++_generation;
    LoginResponse? issuedSession;
    _resetState(notify: false);

    try {
      await _repository.runSharedSsoMutation(() async {
        final response = await _repository.signIn(employeeNumber, password);
        issuedSession = response;
        if (!_isCurrent(generation)) {
          throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
        }

        // 로그인 응답과 로컬 세션 정보를 같은 잠금 안에서 확정한다
        await _repository.saveToken(
          response.token,
          ssoSessionMarker: response.ssoSessionMarker,
        );
        if (!_isCurrent(generation)) {
          throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
        }
        return response;
      });

      final info = await _repository.fetchMyInfo();
      if (!_isCurrent(generation)) {
        throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
      }

      _employeeInfo = info;
      _role = info.role;
      _name = info.name;
      _isLoggedIn = true;
      notifyListeners();
    } catch (loginError, loginStackTrace) {
      // signin 응답까지 받았다면 secure-storage 저장 실패를 포함해 서버에 생긴
      // refresh session을 marker-bound revoke + durable fence로 정리한다.
      // 그 사이 다른 로그인 cookie가 들어왔으면 서버가 marker mismatch로 no-op 처리한다.
      Object? cleanupError;
      StackTrace? cleanupStackTrace;
      final marker = issuedSession?.ssoSessionMarker;
      final cleanupOwnsCurrentGeneration = _isCurrent(generation);
      if (marker != null && marker.isNotEmpty) {
        try {
          await _repository.discardRefreshSession(
            marker,
            clearLocalState: cleanupOwnsCurrentGeneration,
          );
        } catch (error, stackTrace) {
          // 서버 세션 정리까지 실패하면 원래 오류와 함께 전달한다
          cleanupError = error;
          cleanupStackTrace = stackTrace;
        }
      }

      if (_isCurrent(generation)) {
        try {
          await _repository.clearToken();
        } catch (_) {
          // 저장소 오류가 있어도 가능한 서버 정리를 먼저 수행한다
        }
        if (_isCurrent(generation)) _resetState();
      }

      if (cleanupError != null && cleanupStackTrace != null) {
        Error.throwWithStackTrace(cleanupError, cleanupStackTrace);
      }
      Error.throwWithStackTrace(loginError, loginStackTrace);
    }
  }

  // 서버가 세션 만료를 확정하면 로컬 로그인 상태를 지운다
  bool expireSession() {
    ++_generation;
    final wasLoggedIn = _isLoggedIn;
    _resetState();
    return wasLoggedIn;
  }

  // 로컬 상태를 지운 뒤 서버 세션과 알림 연결을 정리한다
  Future<void> logout({String? fcmToken}) async {
    await logoutIfCurrent(_generation, fcmToken: fcmToken);
  }

  // 요청을 시작한 세션이 유지될 때만 로그아웃한다
  /// 오래된 화면 작업의 성공 완료가 새 로그인 세션을 종료하지 못하게 한다.
  Future<bool> logoutIfCurrent(
    int expectedGeneration, {
    String? fcmToken,
  }) async {
    if (!_isCurrent(expectedGeneration)) return false;
    ++_generation;
    _resetState();
    await _repository.logout(fcmToken: fcmToken);
    return true;
  }

  // 이메일 변경 성공 후 현재 화면의 내 정보를 갱신한다
  Future<void> updateEmail(String newEmail) async {
    updateEmailIfCurrent(_generation, newEmail);
  }

  // 이메일 변경 결과를 같은 세션에만 반영한다
  bool updateEmailIfCurrent(int expectedGeneration, String newEmail) {
    if (!_isCurrent(expectedGeneration)) return false;
    final info = _employeeInfo;
    if (info == null) return false;
    _employeeInfo = info.copyWith(email: newEmail);
    notifyListeners();
    return true;
  }
}
