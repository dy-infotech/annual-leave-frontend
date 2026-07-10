import 'dart:convert';

import 'package:annual_leave_frontend/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/stub_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final client = ApiClient();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saves, reads, and clears the authentication token', () async {
    await client.saveToken('jwt-token');

    expect(await client.getToken(), 'jwt-token');

    await client.clearToken();

    expect(await client.getToken(), isNull);
  });

  test('adds a bearer token to outgoing requests', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'jwt-token'});
    late RequestOptions capturedOptions;
    client.dio.httpClientAdapter = StubHttpClientAdapter((options) {
      capturedOptions = options;
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await client.dio.get('/test');

    expect(capturedOptions.headers['Authorization'], 'Bearer jwt-token');
  });

  test('does not add an authorization header without a token', () async {
    late RequestOptions capturedOptions;
    client.dio.httpClientAdapter = StubHttpClientAdapter((options) {
      capturedOptions = options;
      return ResponseBody.fromString(
        jsonEncode({'ok': true}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await client.dio.get('/test');

    expect(capturedOptions.headers, isNot(contains('Authorization')));
  });

  test('uses the API response message for server errors', () async {
    client.dio.httpClientAdapter = StubHttpClientAdapter(
      (_) => ResponseBody.fromString(
        jsonEncode({'message': '인증이 필요합니다.'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    await expectLater(
      client.dio.get('/test'),
      throwsA(
        isA<DioException>().having(
          (error) => error.message,
          'message',
          '인증이 필요합니다.',
        ),
      ),
    );
  });

  test('uses a network error message when there is no response', () async {
    client.dio.httpClientAdapter = StubHttpClientAdapter((options) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      client.dio.get('/test'),
      throwsA(
        isA<DioException>().having(
          (error) => error.message,
          'message',
          '네트워크 오류가 발생했습니다.',
        ),
      ),
    );
  });
}
