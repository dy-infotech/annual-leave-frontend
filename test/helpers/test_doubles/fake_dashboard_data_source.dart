import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/views/DSH001_M01.dart';
import 'package:annual_leave_frontend/providers/dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
    const DashboardScreen(),
    providers: [
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) => _FakeDashboardProvider(
          dataToReturn: data,
          errorMessageToReturn: errorMessage,
        ),
      ),
    ],
  );
  await pumpFor(tester, duration: const Duration(milliseconds: 500));
}

class _FakeDashboardProvider extends DashboardProvider {
  _FakeDashboardProvider({this.dataToReturn, this.errorMessageToReturn});

  final DashboardData? dataToReturn;
  final String? errorMessageToReturn;

  @override
  DashboardData? get data => dataToReturn;

  @override
  String? get errorMessage => errorMessageToReturn;

  @override
  bool get isLoading => false;

  @override
  Future<void> fetchDashboard() async {}
}
