import 'package:annual_leave_frontend/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    show RemoteMessage, FirebaseMessaging;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';

/// 앱이 백그라운드/종료 상태일 때 FCM 메시지를 처리하는 핸들러.
///
/// 별도 isolate에서 실행되므로 Firebase를 다시 초기화해야 하고,
/// 최상위(top-level) 함수여야 한다. (클래스 메서드나 익명 함수로 바꾸면 동작하지 않는다)
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('백그라운드 FCM: ${message.messageId}');
}

/// 앱 진입점. 한국어 날짜 형식과 Firebase를 초기화한 뒤 앱을 시작한다.
/// 로그인 상태 복원과 첫 화면 결정은 [MyApp]의 SplashScreen이 담당한다.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}
