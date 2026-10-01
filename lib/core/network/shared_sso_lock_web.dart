import 'dart:async';
import 'dart:html' as html;
import 'dart:math';

const _lockKey = 'dy_sso_cookie_mutation_lock';
const _lease = Duration(seconds: 30);
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

Future<T> withSharedSsoMutation<T>(Future<T> Function() action) async {
  final owner = _newOwner();

  while (true) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = _parseLock(html.window.localStorage[_lockKey]);

    if (current == null || current.expiresAt <= now) {
      final expiresAt = now + _lease.inMilliseconds;
      final candidate = '$owner|$expiresAt';
      html.window.localStorage[_lockKey] = candidate;

      // localStorage에는 CAS가 없으므로 잠깐 양보한 뒤 소유권을 다시 확인한다.
      // 같은 origin의 여러 탭/앱이 동시에 썼다면 마지막 writer만 진입한다.
      await Future<void>.delayed(_settleDelay);
      if (html.window.localStorage[_lockKey] == candidate) {
        try {
          return await action();
        } finally {
          if (html.window.localStorage[_lockKey] == candidate) {
            html.window.localStorage.remove(_lockKey);
          }
        }
      }
    }

    await Future<void>.delayed(_retryDelay);
  }
}
