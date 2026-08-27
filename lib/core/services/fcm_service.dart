import 'dart:io' show Platform;
import 'dart:async' show StreamSubscription;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/auth/models/auth_models.dart'
    show SyncFcmTokenRequest;

/// FCM 토큰 등록과 알림 리스너 구독을 담당하는 앱 전역 서비스.
///
/// 알림 리스너 구독이 앱 수명주기 동안 1개만 유지되어야 하므로 싱글턴으로 둔다.
/// (기존 DashboardProvider가 전역 등록 provider로서 담당하던 역할)
class FcmService {
  FcmService._internal();

  static final FcmService instance = FcmService._internal();

  final ApiClient _apiClient = ApiClient();

  final String _fcmTokenKey = 'registered_fcm_token';
  String get fcmTokenKey => _fcmTokenKey;

  StreamSubscription? _foregroundNotificationSubscription;
  StreamSubscription? _openedNotificationSubscription;

  /// 관리자 대시보드 조회 성공 후 호출된다.
  /// 토큰이 이전 등록값과 다를 때만 서버에 재전송한다. (기존 동작 유지)
  Future<void> registerTokenAndListeners() async {
    final messaging = FirebaseMessaging.instance;
    try {
      var settings = await messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

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
      if (registeredToken == token) {
        return;
      }

      final deviceOs = kIsWeb
          ? "Web"
          : Platform.isAndroid
              ? "Android"
              : Platform.isIOS
                  ? "iOS"
                  : "Unknown";
      await _apiClient.dio.post(
        '/api/admin/auth/sync-fcm-token',
        data: SyncFcmTokenRequest(
          fcmToken: token,
          deviceOs: deviceOs,
        ).toJson(),
      );
      await prefs.setString(fcmTokenKey, token);
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

    _foregroundNotificationSubscription ??=
        FirebaseMessaging.onMessage.listen((message) {
      // TODO: 실행 도중 alert 팜업 필요할 수도.
      //       나중에 팝업 필요하면 flutter_local_notifications 추가 또는
      //       onMessage에서 local notification 호출
      debugPrint("앱 실행 중 FCM 수신");
      debugPrint(message.notification?.title);
      debugPrint(message.notification?.body);
    });

    _openedNotificationSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // TODO: 알림 클릭시 관련 장소로 네비게이팅 필요할 수도.
      debugPrint("알림 클릭");
      debugPrint(message.data.toString());
    });

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

  Future<void> closeSubscription() async {
    await _foregroundNotificationSubscription?.cancel();
    await _openedNotificationSubscription?.cancel();
    _foregroundNotificationSubscription = null;
    _openedNotificationSubscription = null;
  }
}
