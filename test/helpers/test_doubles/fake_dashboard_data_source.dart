import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/repositories/dashboard_repository.dart';
import 'package:annual_leave_frontend/features/dashboard/views/DSH001_M01.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pump_app.dart';

/// 대시보드 화면을 지정한 상태로 띄우는 헬퍼.
///
/// 대시보드 데이터의 주입 배선은 마이그레이션 단계에 따라 바뀌므로
/// 이 파일에 격리한다. 화면 테스트의 시나리오는 배선과 무관하게 유지된다.
Future<void> pumpDashboardScreen(
  WidgetTester tester, {
  DashboardData? data,
  String? errorMessage,
}) async {
  await pumpApp(
    tester,
    DashboardScreen(
      repository: FakeDashboardRepository(
        dataToReturn: data,
        shouldThrow: errorMessage != null,
      ),
      registerFcm: () async {},
    ),
  );
  await pumpFor(tester, duration: const Duration(milliseconds: 500));
}

/// DashboardRepository 인메모리 페이크.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({this.dataToReturn, this.shouldThrow = false});

  final DashboardData? dataToReturn;
  final bool shouldThrow;

  int fetchCount = 0;

  @override
  Future<DashboardData> fetchDashboard() async {
    fetchCount++;
    if (shouldThrow || dataToReturn == null) {
      throw Exception('dashboard fetch failed');
    }
    return dataToReturn!;
  }
}
