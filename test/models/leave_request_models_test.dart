import 'package:annual_leave_frontend/models/leave_request_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LeaveRequestCreate serializes dates and use days', () {
    final request = LeaveRequestCreate(
      startDate: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 11, 12),
      useDays: 1.5,
    );

    expect(request.toJson(), {
      'startDate': '2026-01-02',
      'endDate': '2026-11-12',
      'useDays': 1.5,
    });
  });

  group('LeaveRequestListItem', () {
    test('deserializes all response fields', () {
      final item = LeaveRequestListItem.fromJson({
        'requestId': 10,
        'employeeName': '홍길동',
        'position': '대리',
        'department': '개발팀',
        'requestedAt': '2026-01-01T09:00:00',
        'startDate': '2026-01-02',
        'endDate': '2026-01-03',
        'useDays': 2,
        'status': 'REJECTED',
        'rejectReason': '일정 조정 필요',
      });

      expect(item.requestId, 10);
      expect(item.employeeName, '홍길동');
      expect(item.position, '대리');
      expect(item.department, '개발팀');
      expect(item.requestedAt, '2026-01-01T09:00:00');
      expect(item.startDate, '2026-01-02');
      expect(item.endDate, '2026-01-03');
      expect(item.useDays, 2.0);
      expect(item.status, 'REJECTED');
      expect(item.rejectReason, '일정 조정 필요');
    });

    test('defaults missing organization fields', () {
      final item = LeaveRequestListItem.fromJson({
        'requestId': 11,
        'employeeName': '김직원',
        'requestedAt': '2026-02-01T09:00:00',
        'startDate': '2026-02-02',
        'endDate': '2026-02-02',
        'useDays': 0.5,
        'status': 'PENDING',
      });

      expect(item.position, isEmpty);
      expect(item.department, isEmpty);
      expect(item.rejectReason, isNull);
    });
  });

  group('PendingLeaveRequest', () {
    test('deserializes all response fields', () {
      final request = PendingLeaveRequest.fromJson({
        'requestId': 12,
        'employeeNumber': 'EMP-003',
        'employeeName': '이대리',
        'department': '인사팀',
        'startDate': '2026-03-02',
        'endDate': '2026-03-04',
        'useDays': 3,
        'createdAt': '2026-03-01T10:00:00',
      });

      expect(request.requestId, 12);
      expect(request.employeeNumber, 'EMP-003');
      expect(request.employeeName, '이대리');
      expect(request.department, '인사팀');
      expect(request.startDate, '2026-03-02');
      expect(request.endDate, '2026-03-04');
      expect(request.useDays, 3.0);
      expect(request.createdAt, '2026-03-01T10:00:00');
    });

    test('defaults a missing department', () {
      final request = PendingLeaveRequest.fromJson({
        'requestId': 13,
        'employeeNumber': 'EMP-004',
        'employeeName': '박사원',
        'startDate': '2026-04-01',
        'endDate': '2026-04-01',
        'useDays': 1,
        'createdAt': '2026-03-20T10:00:00',
      });

      expect(request.department, isEmpty);
    });
  });
}
