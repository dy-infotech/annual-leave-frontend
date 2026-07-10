import 'package:annual_leave_frontend/models/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LeaveInfo converts numeric values to doubles', () {
    final info = LeaveInfo.fromJson({
      'totalLeaveDays': 15,
      'usedLeaveDays': 4.5,
      'remainingLeaveDays': 10.5,
    });

    expect(info.totalLeaveDays, 15.0);
    expect(info.usedLeaveDays, 4.5);
    expect(info.remainingLeaveDays, 10.5);
  });

  test('LeaveRequestSummary deserializes request counts', () {
    final summary = LeaveRequestSummary.fromJson({
      'pendingCount': 2,
      'approvedCount': 3,
      'rejectedCount': 1,
    });

    expect(summary.pendingCount, 2);
    expect(summary.approvedCount, 3);
    expect(summary.rejectedCount, 1);
  });

  group('DashboardData', () {
    final baseJson = {
      'myLeaveInfoResponse': {
        'totalLeaveDays': 15,
        'usedLeaveDays': 5,
        'remainingLeaveDays': 10,
      },
      'myRequestSummary': {
        'pendingCount': 1,
        'approvedCount': 2,
        'rejectedCount': 0,
      },
    };

    test('deserializes employee dashboard data', () {
      final data = DashboardData.fromJson(baseJson);

      expect(data.myLeaveInfo.remainingLeaveDays, 10.0);
      expect(data.myRequestSummary.approvedCount, 2);
      expect(data.allEmployeeRequestSummary, isNull);
    });

    test('deserializes admin request summary when present', () {
      final data = DashboardData.fromJson({
        ...baseJson,
        'allEmployeeRequestSummary': {
          'pendingCount': 4,
          'approvedCount': 8,
          'rejectedCount': 2,
        },
      });

      expect(data.allEmployeeRequestSummary, isNotNull);
      expect(data.allEmployeeRequestSummary!.pendingCount, 4);
      expect(data.allEmployeeRequestSummary!.approvedCount, 8);
      expect(data.allEmployeeRequestSummary!.rejectedCount, 2);
    });
  });
}
