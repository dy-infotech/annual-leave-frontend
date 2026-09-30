import 'package:annual_leave_frontend/features/leave/models/enums/LeaveState.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('PublicHoliday', () {
    test('fromJson은 날짜 문자열을 DateTime으로 파싱한다', () {
      final holiday =
          PublicHoliday.fromJson(fixtureJson('leave/public_holiday.json'));

      expect(holiday.name, '광복절');
      expect(holiday.year, 2026);
      expect(holiday.month, 8);
      expect(holiday.day, 15);
    });
  });

  group('LeaveType', () {
    test('getLabel은 코드에 해당하는 라벨을 돌려준다', () {
      expect(LeaveType.getLabel('FULL'), '연차');
      expect(LeaveType.getLabel('AM_HALF'), '반차(오전)');
      expect(LeaveType.getLabel('PM_HALF'), '반차(오후)');
      expect(LeaveType.getLabel('ALTERNATIVE'), '대체 휴가');
    });

    test('모르는 코드는 기타 라벨로 대체한다', () {
      expect(LeaveType.getLabel('UNKNOWN_CODE'), '기타');
    });
  });

  group('LeaveState', () {
    test('코드와 라벨 매핑이 유지된다', () {
      expect(LeaveState.pending.code, 'PENDING');
      expect(LeaveState.pending.label, '대기');
      expect(LeaveState.approved.code, 'APPROVED');
      expect(LeaveState.rejected.code, 'REJECTED');
      expect(LeaveState.cancelled.code, 'CANCELLED');
    });
  });
}
