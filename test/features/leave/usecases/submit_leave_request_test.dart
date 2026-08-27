import 'package:annual_leave_frontend/core/error/result.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/usecases/submit_leave_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

void main() {
  LeaveRequestListItem existing({
    required String leaveType,
    String status = 'PENDING',
    String startDate = '2026-08-10',
    String? endDate,
  }) {
    final json = fixtureJson('leave/leave_request_list_item.json')
      ..['leaveType'] = leaveType
      ..['status'] = status
      ..['startDate'] = startDate
      ..['endDate'] = endDate ?? startDate;
    return LeaveRequestListItem.fromJson(json);
  }

  group('hasOverlap - 중복 판정 규칙', () {
    final day = DateTime(2026, 8, 10);

    test('기간이 겹치지 않으면 중복이 아니다', () {
      final requests = [existing(leaveType: 'FULL', startDate: '2026-08-12')];
      expect(SubmitLeaveRequest.hasOverlap(requests, day, day, 'FULL'),
          isFalse);
    });

    test('같은 시간대 반차끼리는 중복이다', () {
      final requests = [existing(leaveType: 'AM_HALF')];
      expect(SubmitLeaveRequest.hasOverlap(requests, day, day, 'AM_HALF'),
          isTrue);
    });

    test('같은 날 서로 다른 시간대 반차는 허용된다', () {
      final requests = [existing(leaveType: 'AM_HALF')];
      expect(SubmitLeaveRequest.hasOverlap(requests, day, day, 'PM_HALF'),
          isFalse);
    });

    test('종일 신청이 있으면 어떤 반차든 중복이다', () {
      final requests = [existing(leaveType: 'FULL', status: 'APPROVED')];
      expect(SubmitLeaveRequest.hasOverlap(requests, day, day, 'PM_HALF'),
          isTrue);
    });

    test('반려/취소된 신청은 판정에서 제외된다', () {
      final requests = [
        existing(leaveType: 'FULL', status: 'REJECTED'),
        existing(leaveType: 'FULL', status: 'CANCELLED'),
      ];
      expect(
          SubmitLeaveRequest.hasOverlap(requests, day, day, 'FULL'), isFalse);
    });

    test('여러 날 기간은 하루라도 겹치면 중복이다', () {
      final requests = [
        existing(leaveType: 'FULL', startDate: '2026-08-11', endDate: '2026-08-12'),
      ];
      expect(
        SubmitLeaveRequest.hasOverlap(
            requests, DateTime(2026, 8, 10), DateTime(2026, 8, 11), 'FULL'),
        isTrue,
      );
    });
  });

  group('exceedsRemaining - 잔여 연차 판정', () {
    test('사용 일수가 잔여 연차 이하이면 통과한다', () {
      expect(
        SubmitLeaveRequest.exceedsRemaining(
            useDays: 2.0, remainingLeaveDays: 2.0),
        isFalse,
      );
    });

    test('사용 일수가 잔여 연차를 초과하면 막힌다', () {
      expect(
        SubmitLeaveRequest.exceedsRemaining(
            useDays: 0.5, remainingLeaveDays: 0.0),
        isTrue,
      );
    });
  });

  group('call - 제출', () {
    LeaveRequestCreate request() => LeaveRequestCreate(
          leaveType: 'FULL',
          startDate: DateTime(2026, 8, 10),
          endDate: DateTime(2026, 8, 11),
          useDays: 2.0,
          leaveReason: null,
        );

    test('성공 시 Ok를 돌려준다', () async {
      final fake = FakeLeaveRepository();
      final usecase = SubmitLeaveRequest(repository: fake);

      final result = await usecase(request());

      expect(result, isA<Ok<void>>());
      expect(fake.submittedRequests, hasLength(1));
    });

    test('실패 시 안내 메시지를 담은 Err를 돌려준다', () async {
      final fake = FakeLeaveRepository()..submitErrorToThrow = Exception('x');
      final usecase = SubmitLeaveRequest(repository: fake);

      final result = await usecase(request());

      expect(result, isA<Err<void>>());
      expect((result as Err).failure.message,
          '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.');
    });
  });
}
