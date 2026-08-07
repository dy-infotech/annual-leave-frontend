import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static String get baseUrl {
    //if (kIsWeb) {
<<<<<<< HEAD
    // return 'http://localhost:8080';
=======
    //return 'http://localhost:8080';
>>>>>>> origin/develop
    return 'https://app.dyinfotech.com';
    //}
  }
}
