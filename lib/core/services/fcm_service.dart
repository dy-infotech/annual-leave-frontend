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

// 로그아웃 전에 이전 세션의 알림 정보를 보관한다
class FcmLogoutContext {
  const FcmLogoutContext({
    required this.jwt,
    required this.fcmToken,
  });

  // 로그아웃 직전 액세스 토큰을 보관한다
  final String? jwt;

  // 서버에 등록한 알림 토큰을 보관한다
  final String? fcmToken;
}

// 알림 토큰 등록과 메시지 수신 상태를 관리한다
class FcmService {
  FcmService._internal();

  static final FcmService instance = FcmService._internal();

  final ApiClient _apiClient = ApiClient();

  // 마지막으로 등록한 알림 토큰의 저장 키다
  final String _fcmTokenKey = 'registered_fcm_token';
  String get fcmTokenKey => _fcmTokenKey;

  // 알림 동기화 기준으로 현재 세션 세대를 사용한다
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

  // 권한과 토큰을 확인한 뒤 서버 동기화와 리스너 등록을 진행한다
  Future<void> registerTokenAndListeners() =>
      _serializeLifecycle(_registerTokenAndListeners);

  Future<void> _registerTokenAndListeners() async {
    // 작업 시작 시점의 세대를 고정한다
    final originatingGeneration = _apiClient.sessionGeneration;
    final messaging = FirebaseMessaging.instance;
    try {
      var settings = await messaging.getNotificationSettings();

      // 아직 결정되지 않은 경우에만 알림 권한을 요청한다
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // 웹 환경에서는 웹 푸시 키로 토큰을 발급한다
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

      if (_apiClient.sessionGeneration != originatingGeneration) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (_apiClient.sessionGeneration != originatingGeneration) {
        return;
      }
      final registeredToken = prefs.getString(fcmTokenKey);
      if (registeredToken != token ||
          _lastSyncedAuthGeneration != originatingGeneration) {
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
        if (_apiClient.sessionGeneration != originatingGeneration) {
          // 세션이 바뀌면 이전 알림 등록 작업을 중단한다
          return;
        }
        if (authSessionMarker != null && authSessionMarker.isNotEmpty) {
          await _apiClient.authenticatedRequest(
            '/api/admin/auth/sync-fcm-token',
            method: 'POST',
            data: SyncFcmTokenRequest(
              fcmToken: token,
              deviceOs: deviceOs,
            ).toJson(),
            options: Options(headers: {
              'X-SSO-Session-Marker': authSessionMarker,
            }),
          );
          if (_apiClient.sessionGeneration != originatingGeneration) {
            return;
          }
          await prefs.setString(fcmTokenKey, token);
          if (_apiClient.sessionGeneration != originatingGeneration) {
            return;
          }
          _lastSyncedAuthGeneration = originatingGeneration;
        } else {
          debugPrint('FCM sync skipped: SSO session marker is unavailable');
        }
      }
    } on PlatformException catch (e) {
      // 브라우저에서 알림 기능을 막은 경우 조용히 종료한다
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

      // 초기 알림 이동 처리는 화면 연결 시 추가한다
    }
  }

  // 서버 해제가 어려운 세션은 로컬 알림 상태만 정리한다
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

  // 로그아웃 전에 현재 토큰과 알림 토큰을 보관한다
  Future<FcmLogoutContext> captureLogoutContext() async {
    final prefs = await SharedPreferences.getInstance();
    return FcmLogoutContext(
      jwt: await _apiClient.getToken(),
      fcmToken: prefs.getString(fcmTokenKey),
    );
  }

  // 로그아웃이 끝난 이전 세션의 로컬 알림 상태를 정리한다
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

  // 기존 호출 경로에서도 같은 로그아웃 정리를 수행한다
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

  // 등록된 알림 리스너를 해제한다
  Future<void> closeSubscription() async {
    await _foregroundNotificationSubscription?.cancel();
    await _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription = null;
    _openedNotificationSubscription = null;
  }
}
