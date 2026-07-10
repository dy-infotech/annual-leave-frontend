import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Extracts a user-facing message from an error thrown by an API call.
///
/// The [ApiClient] error interceptor copies the server-provided message
/// (or a network fallback) onto [DioException.message]. This helper prefers
/// that message so the real cause is surfaced to the user instead of being
/// replaced by a generic string, and only falls back to [fallback] when no
/// meaningful message is available.
String messageFromError(Object error, {required String fallback}) {
  if (error is DioException) {
    final message = error.message;
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }
  }
  return fallback;
}

/// Whether [error] represents an authentication/authorization failure
/// (HTTP 401/403), i.e. the stored session is no longer valid.
bool isAuthError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == 401 || status == 403;
  }
  return false;
}

/// Logs an error (and optional stack trace) in debug builds so that handled
/// exceptions remain diagnosable without leaking details to end users.
void logError(String context, Object error, [StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[$context] $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
