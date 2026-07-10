import 'dart:convert';

import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/stub_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('logs in, loads employee info, and logs out', () async {
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter((options) {
      if (options.path == '/api/auth/signin') {
        expect(options.method, 'POST');
        expect(options.data, {
          'employeeNumber': 'EMP-001',
          'password': 'secret',
        });
        return _jsonResponse({
          'token': 'jwt-token',
          'employeeId': 1,
          'name': '홍길동',
          'role': 'ADMIN',
        });
      }

      expect(options.path, '/api/employees/me');
      expect(options.headers['Authorization'], 'Bearer jwt-token');
      return _jsonResponse({
        'employeeNumber': 'EMP-001',
        'name': '홍길동',
        'position': '대리',
        'department': '개발팀',
        'hireDate': '2024-01-02',
        'role': 'ADMIN',
      });
    });
    final provider = AuthProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.login('EMP-001', 'secret');

    expect(provider.isLoggedIn, isTrue);
    expect(provider.isAdmin, isTrue);
    expect(provider.name, '홍길동');
    expect(provider.employeeInfo!.department, '개발팀');
    expect(await ApiClient().getToken(), 'jwt-token');
    expect(notifications, 1);

    await provider.logout();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.isAdmin, isFalse);
    expect(provider.name, isNull);
    expect(provider.employeeInfo, isNull);
    expect(await ApiClient().getToken(), isNull);
    expect(notifications, 2);
  });

  test('submits sign-up credentials', () async {
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter((options) {
      expect(options.method, 'POST');
      expect(options.path, '/api/auth/signup');
      expect(options.data, {
        'employeeNumber': 'EMP-002',
        'password': 'password',
      });
      return _jsonResponse({}, statusCode: 201);
    });
    final provider = AuthProvider();

    await provider.signUp('EMP-002', 'password');

    expect(provider.isLoggedIn, isFalse);
  });

  test('does nothing when auto-login has no saved token', () async {
    final provider = AuthProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.tryAutoLogin();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.employeeInfo, isNull);
    expect(notifications, 0);
  });

  test('restores login state and employee info from a saved token', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'saved-token'});
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter((options) {
      expect(options.path, '/api/employees/me');
      expect(options.headers['Authorization'], 'Bearer saved-token');
      return _jsonResponse({
        'employeeNumber': 'EMP-003',
        'name': '김직원',
        'position': '사원',
        'department': '인사팀',
      });
    });
    final provider = AuthProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.tryAutoLogin();

    expect(provider.isLoggedIn, isTrue);
    expect(provider.employeeInfo!.name, '김직원');
    expect(notifications, 1);
  });

  test('clears an invalid saved token when auto-login fails', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'expired-token'});
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter(
      (_) => _jsonResponse(
        {'message': '토큰이 만료되었습니다.'},
        statusCode: 401,
      ),
    );
    final provider = AuthProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.tryAutoLogin();

    expect(provider.isLoggedIn, isFalse);
    expect(provider.employeeInfo, isNull);
    expect(await ApiClient().getToken(), isNull);
    expect(notifications, 1);
  });
}

ResponseBody _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
