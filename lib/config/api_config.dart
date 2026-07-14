import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
 // ngrok 터널링으로 임시 테스트
 static const bool _useNgrok = false;
 static const String _ngrokUrl = 'https://primsie-alda-sprawly.ngrok-free.dev';

 static String get baseUrl {
   if (_useNgrok) {
     return _ngrokUrl;
   }

   if (kIsWeb) {
     return 'http://localhost:8080';
   }

   if (Platform.isAndroid) {
     return 'http://10.0.2.2:8080';
     // 실제 기기 테스트 시 아래로 교체
     // return 'http://192.168.0.5:8080';
   }

   // iOS 시뮬레이터
   return 'http://localhost:8080';
   // return 'http://192.168.0.5:8080';
 }
}
