import 'dart:async';

Future<void> _tail = Future<void>.value();

Future<T> withSharedSsoMutation<T>(Future<T> Function() action) async {
  final previous = _tail;
  final completer = Completer<void>();
  _tail = completer.future;

  await previous;
  try {
    return await action();
  } finally {
    completer.complete();
  }
}
