import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

class ApiConfig {
 static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

 static String get baseUrl {
   final configuredUrl = _configuredBaseUrl.trim();
   final value = configuredUrl.isNotEmpty ? configuredUrl : _debugBaseUrl;
   final uri = Uri.tryParse(value);

   if (uri == null ||
       !uri.hasScheme ||
       !uri.hasAuthority ||
       uri.userInfo.isNotEmpty ||
       uri.hasQuery ||
       uri.hasFragment) {
     throw StateError('API_BASE_URL must be an absolute URL.');
   }

   final isSecure = uri.scheme == 'https';
   final isLocalDebugUrl =
       kDebugMode && uri.scheme == 'http' && _isLocalHost(uri.host);
   if (!isSecure && !isLocalDebugUrl) {
     throw StateError(
       'API_BASE_URL must use HTTPS outside local debug environments.',
     );
   }

   return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
 }

 static String get _debugBaseUrl {
   if (!kDebugMode) {
     throw StateError(
       'API_BASE_URL is required for profile and release builds.',
     );
   }
   if (kIsWeb) {
     return 'http://localhost:8080';
   }
   if (defaultTargetPlatform == TargetPlatform.android) {
     return 'http://10.0.2.2:8080';
   }
   return 'http://localhost:8080';
 }

 static bool _isLocalHost(String host) =>
     host == 'localhost' ||
     host == '127.0.0.1' ||
     host == '::1' ||
     host == '10.0.2.2';
}
