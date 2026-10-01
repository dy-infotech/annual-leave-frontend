/// 로그인 화면과 Splash가 공유하는 로컬 인증 환경설정 키.
///
/// 기존 버전은 앱 시작 시 항상 세션 복원을 시도했으므로
/// [autoLoginDefault]는 true로 유지해 업그레이드 시 동작을 바꾸지 않는다.
abstract final class AuthPreferences {
  static const rememberEmployeeNumberKey = 'isRememberMe';
  static const savedEmployeeNumberKey = 'savedEmployeeNumber';
  static const autoLoginKey = 'autoLoginEnabled';

  static const autoLoginDefault = true;
}
