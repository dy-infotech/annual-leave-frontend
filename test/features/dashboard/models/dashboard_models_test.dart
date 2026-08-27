import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('DashboardData', () {
    test('fromJson은 내 연차 정보와 신청 현황을 매핑한다', () {
      final data = DashboardData.fromJson(fixtureJson('dashboard/dashboard.json'));

      expect(data.myLeaveInfo.totalLeaveDays, 15.0);
      expect(data.myLeaveInfo.usedLeaveDays, 3.5);
      expect(data.myLeaveInfo.remainingLeaveDays, 11.5);

      expect(data.myRequestSummary.pendingCount, 1);
      expect(data.myRequestSummary.approvedCount, 4);
      expect(data.myRequestSummary.rejectedCount, 0);
    });

    test('관리자 응답이면 전직원 현황이 함께 매핑된다', () {
      final data = DashboardData.fromJson(fixtureJson('dashboard/dashboard.json'));

      expect(data.allEmployeeRequestSummary, isNotNull);
      expect(data.allEmployeeRequestSummary!.pendingCount, 2);
      expect(data.allEmployeeRequestSummary!.approvedCount, 10);
      expect(data.allEmployeeRequestSummary!.rejectedCount, 1);
    });

    test('일반 사용자 응답이면 전직원 현황은 null이다', () {
      final json = fixtureJson('dashboard/dashboard.json')
        ..['allEmployeeRequestSummary'] = null;
      final data = DashboardData.fromJson(json);

      expect(data.allEmployeeRequestSummary, isNull);
    });
  });
}
