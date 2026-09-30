import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/view_models/DSH001_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_dashboard_data_source.dart';

void main() {
  group('DashboardViewModel', () {
    test('조회 성공(관리자) - 데이터가 세팅되고 FCM 등록이 1회 수행된다', () async {
      var fcmCalls = 0;
      final vm = DashboardViewModel(
        repository: FakeDashboardRepository(
          dataToReturn:
              DashboardData.fromJson(fixtureJson('dashboard/dashboard.json')),
        ),
        registerFcm: () async => fcmCalls++,
      );

      await vm.fetchDashboard();

      expect(vm.data, isNotNull);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
      expect(fcmCalls, 1);
    });

    test('조회 성공(일반 사용자) - FCM 등록을 수행하지 않는다', () async {
      var fcmCalls = 0;
      final vm = DashboardViewModel(
        repository: FakeDashboardRepository(
          dataToReturn: DashboardData.fromJson(
              fixtureJson('dashboard/dashboard.json')
                ..['allEmployeeRequestSummary'] = null),
        ),
        registerFcm: () async => fcmCalls++,
      );

      await vm.fetchDashboard();

      expect(vm.data, isNotNull);
      expect(fcmCalls, 0);
    });

    test('조회 실패 - 오류 메시지가 세팅되고 FCM 등록을 수행하지 않는다', () async {
      var fcmCalls = 0;
      final vm = DashboardViewModel(
        repository: FakeDashboardRepository(shouldThrow: true),
        registerFcm: () async => fcmCalls++,
      );

      await vm.fetchDashboard();

      expect(vm.data, isNull);
      expect(vm.errorMessage, '대시보드 정보를 불러오지 못했습니다.');
      expect(fcmCalls, 0);
    });
  });
}
