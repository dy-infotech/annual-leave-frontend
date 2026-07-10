import 'dart:async';

import 'package:dio/dio.dart';

typedef RequestHandler = FutureOr<ResponseBody> Function(
  RequestOptions options,
);

class StubHttpClientAdapter implements HttpClientAdapter {
  StubHttpClientAdapter(this.handler);

  final RequestHandler handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
