import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'dart:math';

const _lockKey = 'dy_sso_cookie_mutation_lock';

// Web Locks API를 지원하지 않는 구형 브라우저에서만 사용하는 fallback lease.
// 주 경로는 navigator.locks의 origin-wide exclusive lock이다.
const _lease = Duration(minutes: 2);
const _heartbeatInterval = Duration(seconds: 10);
const _retryDelay = Duration(milliseconds: 25);
const _settleDelay = Duration(milliseconds: 15);

final _random = Random.secure();

String _newOwner() {
  final randomPart = List<int>.generate(
    16,
    (_) => _random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().microsecondsSinceEpoch}:$randomPart';
}

({String owner, int expiresAt})? _parseLock(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final separator = raw.lastIndexOf('|');
  if (separator <= 0) return null;

  final expiresAt = int.tryParse(raw.substring(separator + 1));
  if (expiresAt == null) return null;
  return (
    owner: raw.substring(0, separator),
    expiresAt: expiresAt,
  );
}

bool _isOwner(String owner) {
  return _parseLock(html.window.localStorage[_lockKey])?.owner == owner;
}

void _renewLease(String owner) {
  final current = _parseLock(html.window.localStorage[_lockKey]);
  if (current?.owner != owner) return;

  final renewedUntil =
      DateTime.now().millisecondsSinceEpoch + _lease.inMilliseconds;
  html.window.localStorage[_lockKey] = '$owner|$renewedUntil';
}

web.LockManager? _webLockManager() {
  final lockManager = web.window.navigator.locks;
  return lockManager;
}

Future<T> _withWebLock<T>(
  web.LockManager lockManager,
  Future<T> Function() action,
) async {
  late T result;

  final callback = ((web.Lock? _) {
    return action().then<void>((value) {
      result = value;
    }).toJS;
  }).toJS;

  await lockManager.request(
    _lockKey,
    callback,
  ).toDart;
  return result;
}

Future<T> _withFallbackLease<T>(Future<T> Function() action) async {
  final owner = _newOwner();

  while (true) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = _parseLock(html.window.localStorage[_lockKey]);

    if (current == null || current.expiresAt <= now) {
      final expiresAt = now + _lease.inMilliseconds;
      html.window.localStorage[_lockKey] = '$owner|$expiresAt';

      // localStorage에는 CAS가 없으므로 이 경로는 구형 브라우저 호환용 fallback이다.
      await Future<void>.delayed(_settleDelay);
      if (_isOwner(owner)) {
        final heartbeat = Timer.periodic(
          _heartbeatInterval,
          (_) => _renewLease(owner),
        );
        try {
          return await action();
        } finally {
          heartbeat.cancel();
          if (_isOwner(owner)) {
            html.window.localStorage.remove(_lockKey);
          }
        }
      }
    }

    await Future<void>.delayed(_retryDelay);
  }
}

Future<T> withSharedSsoMutation<T>(Future<T> Function() action) {
  final lockManager = _webLockManager();
  if (lockManager != null) {
    // 같은 origin의 모든 탭/창에서 브라우저가 보장하는 exclusive lock을 사용한다.
    return _withWebLock(lockManager, action);
  }
  return _withFallbackLease(action);
}
