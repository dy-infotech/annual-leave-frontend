import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/usecases/submit_leave_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// 휴가 종류 enum의 전 종류(7종) 매핑과 반차 판정을 고정한다.
/// (일부 getLabel 케이스는 models/public_holiday_test.dart 에도 있어 중복은 피했다.)
void main() {
  group('LeaveType - 종류 구성', () {
    test('휴가 종류는 7종이고 선언 순서가 화면 표시 순서다', () {
      expect(LeaveType.values, hasLength(7));
      expect(LeaveType.values.map((e) => e.code).toList(), [
        'FULL',
        'AM_HALF',
        'PM_HALF',
        'ALTERNATIVE',
        'PARENTAL',
        'FAMILY',
        'OTHER',
      ]);
    });

    test('코드는 서버 전송값이므로 중복 없이 고유하다', () {
      final codes = LeaveType.values.map((e) => e.code).toSet();

      expect(codes, hasLength(LeaveType.values.length));
    });
  });

  group('LeaveType.getLabel - 라벨 매핑', () {
    test('아직 검증되지 않던 3종의 라벨도 매핑된다', () {
      expect(LeaveType.getLabel('PARENTAL'), '출산 휴가');
      expect(LeaveType.getLabel('FAMILY'), '가족 돌봄');
      expect(LeaveType.getLabel('OTHER'), '기타');
    });

    test('모든 종류에 대해 getLabel(code)는 자신의 label과 같다', () {
      for (final type in LeaveType.values) {
        expect(LeaveType.getLabel(type.code), type.label, reason: type.name);
      }
    });

    test('라벨은 종류마다 서로 다르다', () {
      final labels = LeaveType.values.map((e) => e.label).toSet();

      expect(labels, hasLength(LeaveType.values.length));
    });

    test('빈 문자열과 대소문자가 다른 코드는 기타로 대체된다', () {
      expect(LeaveType.getLabel(''), '기타');
      expect(LeaveType.getLabel('full'), '기타');
      expect(LeaveType.getLabel('am_half'), '기타');
    });
  });

  group('LeaveType - 사용 단위 구분', () {
    test('반차 2종만 반일 단위로 판정된다', () {
      const halfCodes = {'AM_HALF', 'PM_HALF'};

      for (final type in LeaveType.values) {
        expect(
          SubmitLeaveRequest.isHalf(type.code),
          halfCodes.contains(type.code),
          reason: type.label,
        );
      }
    });

    test('모르는 코드는 반차가 아니다 (종일로 취급)', () {
      expect(SubmitLeaveRequest.isHalf('UNKNOWN_CODE'), isFalse);
      expect(SubmitLeaveRequest.isHalf(''), isFalse);
    });
  });

  group('LeaveType - 사유 입력 필요 구분', () {
    // LVE001_M01_view_model.needsReason 이 쓰는 기준 집합.
    // 연차와 반차 2종만 사유 없이 신청할 수 있다.
    const noReasonTypes = {LeaveType.full, LeaveType.amHalf, LeaveType.pmHalf};

    test('사유가 필요한 종류는 대체/출산/가족돌봄/기타 4종이다', () {
      final needsReason =
          LeaveType.values.where((e) => !noReasonTypes.contains(e)).toList();

      expect(needsReason, [
        LeaveType.alternative,
        LeaveType.parental,
        LeaveType.family,
        LeaveType.other,
      ]);
    });
  });
}
