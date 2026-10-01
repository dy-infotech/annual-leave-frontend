import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

const _lockKey = 'dy_sso_cookie_mutation_lock';

// refresh 경로는 marker 조회 + refresh + 충돌 probe + 1회 재시도까지 이어질 수 있다.
// 각 HTTP 요청의 connect/receive timeout을 합치면 30초를 넘길 수 있으므로,
// 짧은 고정 lease만 사용하면 정상 동작 중 다른 탭이 lock을 탈취할 수 있다.
// 2분 lease를 crash recovery 상한으로 두고, owner가 살아 있는 동안 heartbeat로 갱신한다.
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

Future<T> withSharedSsoMutation<T>(Future<T> Function() action) async {
  final owner = _newOwner();

  while (true) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = _parseLock(html.window.localStorage[_lockKey]);

    if (current == null || current.expiresAt <= now) {
      final expiresAt = now + _lease.inMilliseconds;
      html.window.localStorage[_lockKey] = '$owner|$expiresAt';

      // localStorage에는 CAS가 없으므로 잠깐 양보한 뒤 소유권을 다시 확인한다.
      // 같은 origin의 여러 탭/앱이 동시에 썼다면 마지막 writer만 진입한다.
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
          // heartbeat로 expiresAt 값이 바뀌므로 최초 candidate 문자열 비교 대신
          // owner가 여전히 자신인지 확인한 뒤에만 lock을 해제한다.
          if (_isOwner(owner)) {
            html.window.localStorage.remove(_lockKey);
          }
        }
      }
    }

    await Future<void>.delayed(_retryDelay);
  }
}
