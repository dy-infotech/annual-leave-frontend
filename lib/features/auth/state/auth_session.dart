import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/repositories/auth_repository.dart';
import 'package:flutter/foundation.dart';

/// 로그인 세션 상태. 앱 루트에 등록되는 유일한 전역 상태(`Provider`)다.
///
/// 로그인 여부, 역할(role), 이름, 내 정보([Employee])를 보관한다. 서버 호출은 [AuthRepository]에 위임한다.
/// `isAdmin`은 메뉴 노출용이며 보안 경계가 아니다. 실제 권한은 서버가 요청마다 검증한다.
///
/// [_generation]은 로그인/로그아웃/만료/자동 로그인이 시작될 때마다 올라가는 번호다.
/// 비동기 응답이 돌아왔을 때 번호가 달라졌다면 이미 다른 세션으로 넘어간 것이므로 그 결과를 버린다.
/// (ApiClient의 세션 세대와는 별개의 카운터이다)
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

  /// 로그인 관련 상태를 모두 초기화한다. [notify]가 false면 리스너에게 알리지 않는다.
  void _resetState({bool notify = true}) {
    _isLoggedIn = false;
    _role = null;
    _name = null;
    _employeeInfo = null;
    if (notify) notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;

  /// 화면의 비동기 작업이 시작될 때 현재 세션 소유권을 캡처한다.
  /// 반환값은 로컬 side effect를 같은 세션에만 적용하기 위한 opaque fence로 사용한다.
  int captureGeneration() => _generation;

  bool isCurrentGeneration(int generation) => _isCurrent(generation);

  /// 내 정보(/me)를 다시 조회해 세션 상태를 갱신한다.
  ///
  /// 잔여 연차나 권한(관리자 여부, 관리 팀)이 바뀌었을 수 있는 시점에 호출한다.
  /// 조회 중 로그아웃/재로그인이 일어나면 늦게 온 응답은 버린다. 조회 실패 시 예외를 그대로 던진다.
  Future<void> fetchMyInfo() async {
    final generation = _generation;
    final info = await _repository.fetchMyInfo();
    if (!_isCurrent(generation)) return;

    // /me 성공 자체를 현재 세션의 유효성 확인으로 취급한다.
    // 로그아웃/새 로그인으로 generation이 바뀌면 늦은 응답은 위에서 폐기된다.
    _employeeInfo = info;
    _role = info.role;
    _name = info.name;
    _isLoggedIn = true;
    notifyListeners();
  }

  /// 앱 시작 시 저장된 로그인 상태를 복원한다. (SplashScreen에서 호출)
  ///
  /// [enabled]가 false면 이전 access token/session marker를 로컬에서 정리하고
  /// refresh cookie를 이용한 복원은 시도하지 않는다. true면 토큰을 복원(필요하면 갱신)한 뒤
  /// /me로 내 정보를 확인한다. 실패하면 로그아웃 상태가 된다.
  /// 401/403은 물론 그 밖의 오류에서도 저장된 토큰을 지운다.
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

  /// 로그인. 서버 인증 → 토큰 저장 → /me 조회가 모두 성공해야 로그인 상태가 된다.
  ///
  /// 최종 role/name은 로그인 응답이 아니라 /me 응답을 기준으로 한다.
  /// 중간에 다른 로그인/로그아웃이 끼어들어 세대가 바뀌면 StateError로 중단한다.
  /// 실패하면 저장된 토큰을 지우고 예외를 다시 던진다. (화면이 메시지를 표시)
  Future<void> login(String employeeNumber, String password) async {
    final generation = ++_generation;
    LoginResponse? issuedSession;
    _resetState(notify: false);

    try {
      final loginResponse = await _repository.runSharedSsoMutation(() async {
        final response = await _repository.signIn(employeeNumber, password);
        issuedSession = response;
        if (!_isCurrent(generation)) {
          throw StateError('인증 요청이 새 세션으로 대체되었습니다.');
        }

        // signin이 만든 refresh cookie와 대응하는 access token/session marker를
        // lock 해제 전에 함께 확정한다. 다른 탭 로그인은 이 구간 사이에 끼어들 수 없다.
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
          // fence 저장과 서버 revoke가 모두 실패한 경우에는 orphan refresh session을
          // 조용히 남기지 않도록 최종적으로 cleanup 실패를 호출자에게 전파한다.
          cleanupError = error;
          cleanupStackTrace = stackTrace;
        }
      }

      if (_isCurrent(generation)) {
        try {
          await _repository.clearToken();
        } catch (_) {
          // secure storage 장애가 원인인 경우에도 가능한 범위의 서버 cleanup은 위에서 먼저 시도했다.
        }
        if (_isCurrent(generation)) _resetState();
      }

      if (cleanupError != null && cleanupStackTrace != null) {
        Error.throwWithStackTrace(cleanupError, cleanupStackTrace);
      }
      Error.throwWithStackTrace(loginError, loginStackTrace);
    }
  }

  /// 서버에서 세션이 만료됐다고 확정했을 때 호출한다. (토큰 갱신 실패 등)
  ///
  /// 상태만 초기화하고 서버 호출은 하지 않는다. 반환값은 "만료 전에 로그인 상태였는지"이며,
  /// true일 때만 로그인 화면으로 이동시키면 된다.
  bool expireSession() {
    ++_generation;
    final wasLoggedIn = _isLoggedIn;
    _resetState();
    return wasLoggedIn;
  }

  /// 명시적 로그아웃. 로컬 상태를 먼저 지운 뒤 서버에 토큰 폐기를 요청한다.
  /// [fcmToken]을 주면 서버가 해당 기기의 푸시 연결도 함께 해제한다.
  Future<void> logout({String? fcmToken}) async {
    await logoutIfCurrent(_generation, fcmToken: fcmToken);
  }

  /// [expectedGeneration]이 아직 현재 세션일 때만 로그아웃한다.
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

  /// 이메일 변경 성공 후 화면에 보이는 내 정보의 이메일만 로컬에서 갱신한다. (서버 호출 없음)
  /// 내 정보가 없으면 아무것도 하지 않는다.
  Future<void> updateEmail(String newEmail) async {
    updateEmailIfCurrent(_generation, newEmail);
  }

  /// 오래된 이메일 변경 응답이 새 로그인 사용자의 로컬 정보를 덮지 않도록
  /// 요청 시작 시점의 세션 generation이 여전히 현재인지 확인한다.
  bool updateEmailIfCurrent(int expectedGeneration, String newEmail) {
    if (!_isCurrent(expectedGeneration)) return false;
    final info = _employeeInfo;
    if (info == null) return false;
    _employeeInfo = info.copyWith(email: newEmail);
    notifyListeners();
    return true;
  }
}
