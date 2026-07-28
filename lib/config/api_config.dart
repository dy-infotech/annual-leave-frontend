import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    //if (kIsWeb) {
      //return 'http://localhost:8080';
      return 'https://app.dyinfotech.com';
    //}
  }
}
