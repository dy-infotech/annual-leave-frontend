import 'dart:async' show Completer, StreamSubscription;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart' show Options;
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart'
    show SyncFcmTokenRequest;

/// 로그아웃 직전에 캡처해 두는 이전 세션의 정보.
///
/// 로그아웃이 시작되면 저장된 JWT와 등록된 FCM token이 곧 지워지므로,
/// 그 전에 값을 잡아 두었다가 [FcmService.cleanupCapturedLogout]에 넘긴다.
class FcmLogoutContext {
  const FcmLogoutContext({
    required this.jwt,
    required this.fcmToken,
  });

  /// 로그아웃 직전의 액세스 토큰. 없으면 null.
  final String? jwt;

  /// 서버에 등록해 둔 FCM token(SharedPreferences에 저장된 값). 등록한 적이 없으면 null.
  final String? fcmToken;
}

/// FCM 토큰 등록과 알림 리스너 구독을 담당하는 앱 전역 서비스.
///
/// 알림 리스너 구독이 앱 수명주기 동안 1개만 유지되어야 하므로 싱글턴으로 둔다.
/// 등록은 관리자 대시보드 조회가 성공한 뒤에만 일어난다. (서버 등록 경로도 `/api/admin/` 하위다)
///
/// 세션 세대(`ApiClient.sessionGeneration`) 확인이 곳곳에 있는 이유: 정리 작업은 비동기로
/// 진행되므로, 그 사이 새로 로그인한 사용자의 토큰/설정을 지우지 않기 위해서다.
class FcmService {
  FcmService._internal();

  static final FcmService instance = FcmService._internal();

  final ApiClient _apiClient = ApiClient();

  /// 서버에 마지막으로 등록한 FCM token을 보관하는 SharedPreferences 키.
  final String _fcmTokenKey = 'registered_fcm_token';
  String get fcmTokenKey => _fcmTokenKey;

  // access JWT는 같은 로그인 세션 안에서도 refresh될 수 있으므로 JWT 문자열이 아니라
  // ApiClient의 세션 세대를 마지막 sync 기준으로 사용한다.
  int? _lastSyncedAuthGeneration;

  StreamSubscription? _foregroundNotificationSubscription;
  StreamSubscription? _openedNotificationSubscription;
  Future<void> _lifecycleMutation = Future<void>.value();

  Future<T> _serializeLifecycle<T>(Future<T> Function() action) async {
    final previous = _lifecycleMutation;
    final completer = Completer<void>();
    _lifecycleMutation = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// 알림 권한 요청 → FCM token 발급 → 서버 동기화 → 알림 리스너 등록을 수행한다.
  ///
  /// 관리자 대시보드 조회 성공 후 호출된다. 대시보드를 조회할 때마다 호출되므로 여러 번 실행돼도 안전해야 한다.
  /// - 서버 동기화는 token이 바뀌었거나 로그인 세션(JWT)이 바뀐 경우에만 한다.
  /// - 리스너는 이미 등록돼 있으면 다시 등록하지 않는다. (`??=`)
  /// - 권한 거부, 브라우저 차단, token 발급 지연(10초) 등은 로그만 남기고 조용히 넘어간다.
  ///   알림을 못 받아도 앱 사용에는 영향이 없어야 하기 때문이다.
  Future<void> registerTokenAndListeners() =>
      _serializeLifecycle(_registerTokenAndListeners);

  Future<void> _registerTokenAndListeners() async {
    final messaging = FirebaseMessaging.instance;
    try {
      var settings = await messaging.getNotificationSettings();

      // 아직 사용자에게 물어본 적이 없을 때만 권한을 요청한다. (이미 거부된 경우 다시 묻지 않음)
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // vapidKey는 웹 푸시용 공개 키다. 웹에서만 필요하다.
      final token = await messaging
          .getToken(
        vapidKey: kIsWeb
            ? "BK0OMc8V4bjy1iL0C1OUY2L_u3XaMHaHAdyMjDnmXTeDPb1LALjEeYQDZD_uQ0VkYVZIiArZ9OMSwRC7NPZBjfI"
            : null,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint("FCM token timeout");
        return null;
      });
      if (token == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final registeredToken = prefs.getString(fcmTokenKey);
      final currentGeneration = _apiClient.sessionGeneration;
      if (registeredToken != token ||
          _lastSyncedAuthGeneration != currentGeneration) {
        final deviceOs = kIsWeb
            ? 'Web'
            : switch (defaultTargetPlatform) {
                TargetPlatform.android => 'Android',
                TargetPlatform.iOS => 'iOS',
                TargetPlatform.macOS => 'macOS',
                TargetPlatform.windows => 'Windows',
                TargetPlatform.linux => 'Linux',
                TargetPlatform.fuchsia => 'Fuchsia',
              };
        final authSessionMarker = await _apiClient.getSessionMarker();
        if (authSessionMarker != null && authSessionMarker.isNotEmpty) {
          await _apiClient.dio.post(
            '/api/admin/auth/sync-fcm-token',
            data: SyncFcmTokenRequest(
              fcmToken: token,
              deviceOs: deviceOs,
            ).toJson(),
            options: Options(headers: {
              'X-SSO-Session-Marker': authSessionMarker,
            }),
          );
          await prefs.setString(fcmTokenKey, token);
          _lastSyncedAuthGeneration = currentGeneration;
        } else {
          debugPrint('FCM sync skipped: SSO session marker is unavailable');
        }
      }
    } on PlatformException catch (e) {
      // 시크릿 모드 등 브라우저에서 차단한 경우 에러 잡아내기
      if (e.code == 'permission-blocked' ||
          e.message?.contains('permission-blocked') == true) {
        debugPrint('시크릿 모드 또는 브라우저 정책에 의해 알림 권한이 차단되었습니다.');
      } else {
        debugPrint('기타 플랫폼 에러 발생: ${e.message}');
      }
    } catch (e) {
      debugPrint('알 수 없는 에러 발생: $e');
    }

    // 앱이 포그라운드일 때 수신한 알림
    _foregroundNotificationSubscription ??=
        FirebaseMessaging.onMessage.listen((message) {
      // TODO: 실행 도중 alert 팝업 필요할 수도.
      //       나중에 팝업 필요하면 flutter_local_notifications 추가 또는
      //       onMessage에서 local notification 호출
      debugPrint("앱 실행 중 FCM 수신");
      debugPrint(message.notification?.title);
      debugPrint(message.notification?.body);
    });

    // 백그라운드 상태에서 알림을 눌러 앱이 열린 경우
    _openedNotificationSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // TODO: 알림 클릭시 관련 장소로 네비게이팅 필요할 수도.
      debugPrint("알림 클릭");
      debugPrint(message.data.toString());
    });

    // 앱이 종료된 상태에서 알림을 눌러 실행된 경우
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("종료 상태에서 알림 클릭");
      debugPrint(initialMessage.data.toString());

      // TODO: 해당 메시지를 파싱해서 신청 승인 목록으로 이동하는 네비게이팅 코드 필요.
      //       현재 코드는 임시 의사 코드
      // final type = initialMessage.data['type'];

      // if (type == 'approval') {
      //   final approvalId = initialMessage.data['approvalId'];

      //   // 승인 상세 화면 이동
      //   navigatorKey.currentState?.pushNamed(
      //     '/approval-detail',
      //     arguments: approvalId,
      //   );
      // }
    }
  }

  /// 인증 만료처럼 서버 unregister를 보장할 수 없는 경우의 로컬 FCM 정리.
  ///
  /// 만료된 JWT로 /api/auth/logout을 다시 호출하지 않고 현재 Firebase token과
  /// 리스너를 폐기한다. 다음 로그인 시 새 token이 발급되어 owner가 다시 동기화된다.
  ///
  /// [expectedAuthGeneration]이 주어지면 각 단계 사이에서 현재 세션 세대와 비교해,
  /// 그 사이 새 로그인이 시작됐다면 즉시 중단한다. (새 세션의 token/설정을 지우지 않기 위함)
  Future<void> clearLocalStateAfterSessionExpiry({
    int? expectedAuthGeneration,
  }) =>
      _serializeLifecycle(
        () => _clearLocalStateAfterSessionExpiry(
          expectedAuthGeneration: expectedAuthGeneration,
        ),
      );

  Future<void> _clearLocalStateAfterSessionExpiry({
    int? expectedAuthGeneration,
  }) async {
    if (expectedAuthGeneration != null &&
        _apiClient.sessionGeneration != expectedAuthGeneration) {
      return;
    }

    _lastSyncedAuthGeneration = null;
    await closeSubscription();

    if (expectedAuthGeneration != null &&
        _apiClient.sessionGeneration != expectedAuthGeneration) {
      return;
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('FCM 클라이언트 토큰 폐기 실패: $e');
    }

    if (expectedAuthGeneration != null &&
        _apiClient.sessionGeneration != expectedAuthGeneration) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(fcmTokenKey);
  }

  /// 명시적 로그아웃 전에 이전 세션의 JWT/FCM token을 캡처한다.
  Future<FcmLogoutContext> captureLogoutContext() async {
    final prefs = await SharedPreferences.getInstance();
    return FcmLogoutContext(
      jwt: await _apiClient.getToken(),
      fcmToken: prefs.getString(fcmTokenKey),
    );
  }

  /// 로컬 로그아웃이 확정된 뒤 이 기기의 FCM 상태(Firebase token, 리스너, 저장된 token)를 정리한다.
  ///
  /// 서버 쪽 FCM 해제는 로그아웃 요청(`AuthSession.logout(fcmToken: ...)`)에 token이 실려 이미 처리되므로
  /// 여기서는 로컬 정리만 한다. [context]는 현재 구현에서 사용하지 않는다.
  /// 이후 새 로그인이 시작되면 auth generation이 달라지므로 새 세션의
  /// Firebase token/prefs는 건드리지 않는다.
  Future<void> cleanupCapturedLogout(
    FcmLogoutContext context, {
    required int expectedAuthGeneration,
  }) async {
    if (_apiClient.sessionGeneration != expectedAuthGeneration) {
      return;
    }

    await clearLocalStateAfterSessionExpiry(
      expectedAuthGeneration: expectedAuthGeneration,
    );
  }

  /// 하위 호환용. 가능하면 captureLogoutContext + 로컬 logout +
  /// cleanupCapturedLogout 순서를 사용한다.
  Future<void> unregisterToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(fcmTokenKey);

    await _apiClient.logoutSession(
      fcmToken: token != null && token.isNotEmpty ? token : null,
    );
    await clearLocalStateAfterSessionExpiry(
      expectedAuthGeneration: _apiClient.sessionGeneration,
    );
  }

  /// 포그라운드/알림 클릭 리스너를 해제한다. 다음 [registerTokenAndListeners]에서 다시 등록된다.
  Future<void> closeSubscription() async {
    await _foregroundNotificationSubscription?.cancel();
    await _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription = null;
    _openedNotificationSubscription = null;
  }
}
