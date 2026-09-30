import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('LeaveRequestCreate', () {
    test('toJson은 날짜를 yyyy-MM-dd로 0 채움 포맷한다', () {
      final json = LeaveRequestCreate(
        leaveType: 'FULL',
        startDate: DateTime(2026, 8, 3),
        endDate: DateTime(2026, 12, 24),
        useDays: 2.0,
        leaveReason: null,
      ).toJson();

      expect(json['startDate'], '2026-08-03');
      expect(json['endDate'], '2026-12-24');
      expect(json['leaveType'], 'FULL');
      expect(json['useDays'], 2.0);
      expect(json['leaveReason'], isNull);
    });

    test('연차/반차 외 휴가는 사유가 body에 포함된다', () {
      final json = LeaveRequestCreate(
        leaveType: 'FAMILY',
        startDate: DateTime(2026, 8, 3),
        endDate: DateTime(2026, 8, 3),
        useDays: 1.0,
        leaveReason: '가족 돌봄',
      ).toJson();

      expect(json['leaveReason'], '가족 돌봄');
    });
  });

  group('LeaveRequestListItem', () {
    test('fromJson은 응답 필드를 매핑하고 useDays를 double로 변환한다', () {
      final item = LeaveRequestListItem.fromJson(
          fixtureJson('leave/leave_request_list_item.json'));

      expect(item.requestId, 11);
      expect(item.employeeName, '홍길동');
      expect(item.employeeNumber, 'A0001');
      expect(item.leaveType, 'FULL');
      expect(item.useDays, 2.0);
      expect(item.status, 'PENDING');
      expect(item.rejectReason, isNull);
    });

    test('직급/부서/팀이 없으면 빈 문자열로 채운다', () {
      final json = fixtureJson('leave/leave_request_list_item.json')
        ..remove('position')
        ..remove('department')
        ..remove('team');
      final item = LeaveRequestListItem.fromJson(json);

      expect(item.position, '');
      expect(item.department, '');
      expect(item.team, '');
    });
  });

  group('LeaveRequestDetail', () {
    test('fromJson은 휴가자/휴가 정보/결재자 정보를 매핑한다', () {
      final detail = LeaveRequestDetail.fromJson(
          fixtureJson('leave/leave_request_detail.json'));

      expect(detail.employeeName, '홍길동');
      expect(detail.leaveType, 'AM_HALF');
      expect(detail.useDays, 0.5);
      expect(detail.status, 'APPROVED');
      expect(detail.leaveReason, '개인 사유');
      expect(detail.approverName, '김결재');
      expect(detail.managedAt, '2026-08-02');
    });

    test('빈 응답이어도 기본값으로 파싱된다', () {
      final detail = LeaveRequestDetail.fromJson(const {});

      expect(detail.employeeNumber, '');
      expect(detail.leaveType, 'FULL');
      expect(detail.useDays, 0.0);
      expect(detail.leaveReason, isNull);
      expect(detail.approverNumber, isNull);
    });
  });

  group('PendingLeaveRequest', () {
    test('fromJson은 응답 필드를 매핑하고 useDays를 double로 변환한다', () {
      final pending = PendingLeaveRequest.fromJson(
          fixtureJson('leave/pending_leave_request.json'));

      expect(pending.requestId, 21);
      expect(pending.employeeName, '이신청');
      expect(pending.useDays, 2.0);
      expect(pending.createdAt, '2026-08-20');
      expect(pending.leaveType, 'FULL');
    });
  });
}
