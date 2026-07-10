import 'dart:convert';

import 'package:annual_leave_frontend/providers/dashboard_provider.dart';
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

  test('loads dashboard data and clears loading state', () async {
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter((options) {
      expect(options.method, 'GET');
      expect(options.path, '/api/dashboard');
      return ResponseBody.fromString(
        jsonEncode({
          'myLeaveInfoResponse': {
            'totalLeaveDays': 15,
            'usedLeaveDays': 3,
            'remainingLeaveDays': 12,
          },
          'myRequestSummary': {
            'pendingCount': 1,
            'approvedCount': 2,
            'rejectedCount': 0,
          },
          'allEmployeeRequestSummary': null,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
    final provider = DashboardProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final request = provider.fetchDashboard();

    expect(provider.isLoading, isTrue);
    expect(provider.errorMessage, isNull);

    await request;

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.data!.myLeaveInfo.remainingLeaveDays, 12.0);
    expect(provider.data!.myRequestSummary.approvedCount, 2);
    expect(notifications, 2);
  });

  test('exposes a user-facing error when the request fails', () async {
    ApiClient().dio.httpClientAdapter = StubHttpClientAdapter(
      (_) => ResponseBody.fromString(
        jsonEncode({'message': '서버 오류'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final provider = DashboardProvider();

    await provider.fetchDashboard();

    expect(provider.isLoading, isFalse);
    expect(provider.data, isNull);
    expect(provider.errorMessage, '대시보드 정보를 불러오지 못했습니다.');
  });
}
