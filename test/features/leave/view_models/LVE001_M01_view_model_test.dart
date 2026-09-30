import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE001_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_auth_session.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';
import '../../../helpers/test_doubles/fake_public_holiday_repository.dart';

void main() {
  late FakeLeaveRepository fake;
  late FakePublicHolidayRepository fakeHolidays;
  late FakeAuthSession fakeAuth;

  setUp(() {
    fake = FakeLeaveRepository();
    fakeHolidays = FakePublicHolidayRepository();
    fakeAuth = FakeAuthSession(
      employeeInfo: Employee.fromJson(fixtureJson('admin/employee.json')),
    );
  });

  LeaveRequestViewModel buildVm() => LeaveRequestViewModel(
        authProvider: fakeAuth,
        repository: fake,
        holidayRepository: fakeHolidays,
      );

  /// 종일 휴가 기간을 시작일 -> 종료일 순서로 선택한다.
  void selectRange(LeaveRequestViewModel vm, DateTime start, DateTime end) {
    vm.selectDay(start, start);
    vm.selectDay(end, end);
  }

  LeaveRequestListItem existing({
    required String leaveType,
    required String status,
    required String startDate,
    String? endDate,
  }) {
    final json = fixtureJson('leave/leave_request_list_item.json')
      ..['leaveType'] = leaveType
      ..['status'] = status
      ..['startDate'] = startDate
      ..['endDate'] = endDate ?? startDate;
    return LeaveRequestListItem.fromJson(json);
  }

  group('load', () {
    test('내 정보, 내 신청 목록, 공휴일을 조회한다', () async {
      final vm = buildVm();

      await vm.load();

      expect(fakeAuth.fetchMyInfoCount, 1);
      expect(fake.myLeaveRequestQueries, hasLength(1));
    });
  });

  group('selectDay - 기간 선택', () {
    test('종일: 시작일 선택 후 종료일 선택 시 주말 제외 일수가 계산된다', () async {
      // 2026-08-07(금) ~ 2026-08-10(월): 주말 제외 2일
      final vm = buildVm();

      var confirmed = vm.selectDay(DateTime(2026, 8, 7), DateTime(2026, 8, 7));
      expect(confirmed, isFalse);
      expect(vm.useDaysText, '0');

      confirmed = vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      expect(confirmed, isTrue);
      expect(vm.useDaysText, '2');
    });

    test('공휴일은 사용 일수 계산에서 제외된다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '광복절 대체', date: DateTime(2026, 8, 10)),
      ];
      final vm = buildVm();
      await vm.load();

      vm.selectDay(DateTime(2026, 8, 7), DateTime(2026, 8, 7));
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.useDaysText, '1'); // 금요일 하루만
    });

    test('시작일보다 앞선 날짜를 선택하면 시작일이 교체된다', () {
      final vm = buildVm();

      vm.selectDay(DateTime(2026, 8, 12), DateTime(2026, 8, 12));
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.startDate, DateTime(2026, 8, 10));
      expect(vm.endDate, isNull);
    });

    test('반차: 하루 선택으로 0.5일이 확정된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);

      final confirmed =
          vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(confirmed, isTrue);
      expect(vm.startDate, vm.endDate);
      expect(vm.useDaysText, '0.5');
    });

    test('반차(오후)도 하루 선택으로 0.5일이 확정된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.pmHalf);

      final confirmed =
          vm.selectDay(DateTime(2026, 8, 11), DateTime(2026, 8, 11));

      expect(confirmed, isTrue);
      expect(vm.startDate, DateTime(2026, 8, 11));
      expect(vm.endDate, DateTime(2026, 8, 11));
      expect(vm.useDays, 0.5);
    });

    test('반차는 이미 기간이 확정된 상태에서 다른 날을 눌러도 그 날 하루로 갱신된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      final confirmed =
          vm.selectDay(DateTime(2026, 8, 12), DateTime(2026, 8, 12));

      expect(confirmed, isTrue);
      expect(vm.startDate, DateTime(2026, 8, 12));
      expect(vm.endDate, DateTime(2026, 8, 12));
      expect(vm.useDaysText, '0.5');
    });

    test('세 번째 선택은 기간을 초기화하고 새 시작일이 된다', () {
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      final confirmed =
          vm.selectDay(DateTime(2026, 8, 17), DateTime(2026, 8, 17));

      expect(confirmed, isFalse);
      expect(vm.startDate, DateTime(2026, 8, 17));
      expect(vm.endDate, isNull);
      expect(vm.useDaysText, '0');
    });

    test('날짜를 새로 선택하면 이전 오류 메시지가 지워진다', () {
      final vm = buildVm();
      vm.setError('날짜를 선택해주세요.');

      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.errorMessage, isNull);
    });

    test('선택한 날짜가 포커스 날짜로 반영된다', () {
      final vm = buildVm();

      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 9, 1));

      expect(vm.focusedDay, DateTime(2026, 9, 1));
    });
  });

  group('일수 계산 - 주말/공휴일/경계', () {
    test('하루짜리 종일 휴가(시작일==종료일)는 1일이다', () {
      final vm = buildVm();

      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      final confirmed =
          vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(confirmed, isTrue);
      expect(vm.useDaysText, '1');
      expect(vm.useDays, 1.0);
    });

    test('다일 종일 휴가는 주말을 제외하고 계산한다', () {
      // 2026-08-10(월) ~ 2026-08-17(월): 토/일 2일을 빼고 6일
      final vm = buildVm();

      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 17));

      expect(vm.useDaysText, '6');
    });

    test('시작일이 공휴일이면 시작일이 계산에서 빠진다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '임시공휴일', date: DateTime(2026, 8, 10)),
      ];
      final vm = buildVm();
      await vm.load();

      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      expect(vm.useDaysText, '2'); // 11(화), 12(수)
    });

    test('기간 중간의 공휴일도 계산에서 빠진다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '임시공휴일', date: DateTime(2026, 8, 11)),
      ];
      final vm = buildVm();
      await vm.load();

      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      expect(vm.useDaysText, '2'); // 10(월), 12(수)
    });

    test('전 구간이 주말이면 사용 일수가 0이 된다', () {
      // 2026-08-08(토) ~ 2026-08-09(일)
      final vm = buildVm();

      vm.selectDay(DateTime(2026, 8, 8), DateTime(2026, 8, 8));
      final confirmed = vm.selectDay(DateTime(2026, 8, 9), DateTime(2026, 8, 9));

      // 기간 자체는 확정되지만 사용 일수는 0이라 화면에서 제출이 막히는 분기다.
      expect(confirmed, isTrue);
      expect(vm.useDaysText, '0');
      expect(vm.useDays, lessThanOrEqualTo(0));
    });

    test('전 구간이 주말과 공휴일이면 사용 일수가 0이 된다', () async {
      // 2026-08-08(토) ~ 2026-08-10(월), 10일은 공휴일
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '임시공휴일', date: DateTime(2026, 8, 10)),
      ];
      final vm = buildVm();
      await vm.load();

      selectRange(vm, DateTime(2026, 8, 8), DateTime(2026, 8, 10));

      expect(vm.useDays, lessThanOrEqualTo(0));
    });

    test('월 경계를 걸친 기간도 주말을 빼고 계산한다', () {
      // 2026-08-31(월) ~ 2026-09-02(수): 3영업일
      final vm = buildVm();

      selectRange(vm, DateTime(2026, 8, 31), DateTime(2026, 9, 2));

      expect(vm.useDaysText, '3');
    });

    test('연말에서 연초로 걸친 기간도 계산된다', () {
      // 2026-12-31(목) ~ 2027-01-04(월): 12/31, 1/1, 1/4 = 3영업일
      final vm = buildVm();

      selectRange(vm, DateTime(2026, 12, 31), DateTime(2027, 1, 4));

      expect(vm.useDaysText, '3');
    });

    test('연초 공휴일이 있으면 연말~연초 기간에서 빠진다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '신정', date: DateTime(2027, 1, 1)),
      ];
      final vm = buildVm();
      await vm.load();

      selectRange(vm, DateTime(2026, 12, 31), DateTime(2027, 1, 4));

      expect(vm.useDaysText, '2'); // 12/31(목), 1/4(월)
    });

    test('공휴일 판정은 연/월/일이 모두 같을 때만 참이다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '광복절', date: DateTime(2026, 8, 15)),
      ];
      final vm = buildVm();
      await vm.load();

      expect(vm.isHoliday(DateTime(2026, 8, 15)), isTrue);
      expect(vm.isHoliday(DateTime(2027, 8, 15)), isFalse);
      expect(vm.isHoliday(DateTime(2026, 9, 15)), isFalse);
      expect(vm.isHoliday(DateTime(2026, 8, 14)), isFalse);
    });

    test('공휴일 조회가 실패하면 공휴일 없이 계산한다', () async {
      fakeHolidays.errorToThrow = Exception('공휴일 API 장애');
      final vm = buildVm();
      await vm.load();

      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      expect(vm.useDaysText, '3');
    });

    test('반차는 주말을 선택해도 0.5일로 확정된다', () {
      // 발견한 문제: 반차 경로는 주말/공휴일 검사를 거치지 않는다.
      // 캘린더에도 선택 제한이 없어 토요일 반차 신청이 서버까지 전달된다.
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);

      vm.selectDay(DateTime(2026, 8, 8), DateTime(2026, 8, 8));

      expect(vm.useDaysText, '0.5');
    });

    test('반차는 공휴일을 선택해도 0.5일로 확정된다', () async {
      // 발견한 문제: 위와 같은 원인으로 공휴일 반차도 막히지 않는다.
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '광복절', date: DateTime(2026, 8, 17)),
      ];
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.pmHalf);

      vm.selectDay(DateTime(2026, 8, 17), DateTime(2026, 8, 17));

      expect(vm.useDaysText, '0.5');
    });
  });

  group('isInRange - 기간 포함 판정', () {
    test('시작일이 없으면 항상 false다', () {
      final vm = buildVm();

      expect(vm.isInRange(DateTime(2026, 8, 10)), isFalse);
    });

    test('종료일이 없으면 시작일 하루만 포함한다', () {
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.endDate, isNull);
      expect(vm.isInRange(DateTime(2026, 8, 10)), isTrue);
      expect(vm.isInRange(DateTime(2026, 8, 11)), isFalse);
      expect(vm.isInRange(DateTime(2026, 8, 9)), isFalse);
    });

    test('시작일과 종료일 경계를 모두 포함한다', () {
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      expect(vm.isInRange(DateTime(2026, 8, 9)), isFalse);
      expect(vm.isInRange(DateTime(2026, 8, 10)), isTrue);
      expect(vm.isInRange(DateTime(2026, 8, 11)), isTrue);
      expect(vm.isInRange(DateTime(2026, 8, 12)), isTrue);
      expect(vm.isInRange(DateTime(2026, 8, 13)), isFalse);
    });

    test('주말과 공휴일도 기간 안에 있으면 포함으로 판정한다', () async {
      fakeHolidays.holidaysToReturn = [
        PublicHoliday(name: '임시공휴일', date: DateTime(2026, 8, 11)),
      ];
      final vm = buildVm();
      await vm.load();
      selectRange(vm, DateTime(2026, 8, 7), DateTime(2026, 8, 12));

      expect(vm.isInRange(DateTime(2026, 8, 8)), isTrue); // 토
      expect(vm.isInRange(DateTime(2026, 8, 11)), isTrue); // 공휴일
    });
  });

  group('setLeaveType - 종류 변경', () {
    test('여러 날 선택 상태에서 반차로 바꾸면 선택이 초기화된다', () {
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 12), DateTime(2026, 8, 12));

      vm.setLeaveType(LeaveType.pmHalf);

      expect(vm.startDate, isNull);
      expect(vm.endDate, isNull);
      expect(vm.useDaysText, '0');
    });

    test('하루 선택 상태에서 반차로 바꾸면 0.5일로 동기화된다', () {
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      vm.setLeaveType(LeaveType.amHalf);

      expect(vm.endDate, vm.startDate);
      expect(vm.useDaysText, '0.5');
    });

    test('사유 입력란은 연차/반차 외 종류에서만 필요하다', () {
      final vm = buildVm();

      expect(vm.setLeaveType(LeaveType.family), isTrue);
      expect(vm.needsReason, isTrue);
      expect(vm.setLeaveType(LeaveType.full), isFalse);
      expect(vm.needsReason, isFalse);
    });

    test('날짜 미선택 상태에서 반차를 고르면 사용 일수만 0.5로 표시된다', () {
      final vm = buildVm();

      final showsReason = vm.setLeaveType(LeaveType.amHalf);

      expect(showsReason, isFalse);
      expect(vm.startDate, isNull);
      expect(vm.endDate, isNull);
      expect(vm.useDaysText, '0.5'); // 날짜가 없는데도 0.5로 먼저 표시된다
    });

    test('시작일만 선택된 상태에서 반차로 바꾸면 종료일이 시작일로 채워진다', () {
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      expect(vm.endDate, isNull);

      vm.setLeaveType(LeaveType.pmHalf);

      expect(vm.startDate, DateTime(2026, 8, 10));
      expect(vm.endDate, DateTime(2026, 8, 10));
      expect(vm.useDaysText, '0.5');
    });

    test('반차에서 종일로 되돌리면 선택된 하루가 1일로 재계산된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      vm.setLeaveType(LeaveType.full);

      expect(vm.useDaysText, '1');
      expect(vm.startDate, DateTime(2026, 8, 10));
      expect(vm.endDate, DateTime(2026, 8, 10));
    });

    test('반차에서 종일로 되돌릴 때 선택된 날짜가 없으면 0이 된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf); // 날짜 없이 0.5
      expect(vm.useDaysText, '0.5');

      vm.setLeaveType(LeaveType.full);

      expect(vm.useDaysText, '0');
    });

    test('주말 반차에서 종일로 되돌리면 0일로 재계산된다', () {
      // 반차 경로에서는 0.5였던 주말이 종일 재계산에서는 0이 된다.
      final vm = buildVm();
      vm.setLeaveType(LeaveType.pmHalf);
      vm.selectDay(DateTime(2026, 8, 8), DateTime(2026, 8, 8)); // 토
      expect(vm.useDaysText, '0.5');

      vm.setLeaveType(LeaveType.full);

      expect(vm.useDaysText, '0');
    });

    test('반차끼리 바꿔도 이미 확정된 0.5일과 선택 날짜가 유지된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      vm.setLeaveType(LeaveType.pmHalf);

      expect(vm.selectedLeaveType, LeaveType.pmHalf);
      expect(vm.startDate, DateTime(2026, 8, 10));
      expect(vm.useDaysText, '0.5');
    });

    test('종일 계열 종류끼리 바꿔도 계산된 일수는 그대로다', () {
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));
      expect(vm.useDaysText, '3');

      for (final type in [
        LeaveType.alternative,
        LeaveType.parental,
        LeaveType.family,
        LeaveType.other,
        LeaveType.full,
      ]) {
        vm.setLeaveType(type);
        expect(vm.selectedLeaveType, type);
        expect(vm.useDaysText, '3', reason: '${type.label}에서 일수가 바뀌면 안 된다');
      }
    });
  });

  group('휴가 종류별 일수 계산 매트릭스', () {
    /// 종일 단위(1일 이상)로 계산되는 종류
    const dayUnitTypes = [
      LeaveType.full,
      LeaveType.alternative,
      LeaveType.parental,
      LeaveType.family,
      LeaveType.other,
    ];

    /// 반일 단위(0.5일)로 계산되는 종류
    const halfUnitTypes = [LeaveType.amHalf, LeaveType.pmHalf];

    for (final type in dayUnitTypes) {
      test('${type.label}: 3영업일 기간은 3일로 계산된다', () {
        final vm = buildVm();
        vm.setLeaveType(type);

        selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

        expect(vm.useDaysText, '3');
        expect(vm.useDays, 3.0);
      });

      test('${type.label}: 주말이 낀 기간도 주말을 제외한다', () {
        final vm = buildVm();
        vm.setLeaveType(type);

        selectRange(vm, DateTime(2026, 8, 7), DateTime(2026, 8, 10));

        expect(vm.useDaysText, '2'); // 금, 월
      });
    }

    for (final type in halfUnitTypes) {
      test('${type.label}: 하루 선택으로 0.5일이 된다', () {
        final vm = buildVm();
        vm.setLeaveType(type);

        final confirmed =
            vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

        expect(confirmed, isTrue);
        expect(vm.useDays, 0.5);
      });

      test('${type.label}: 여러 날이 선택된 상태로 바꾸면 선택이 초기화된다', () {
        final vm = buildVm();
        selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

        vm.setLeaveType(type);

        expect(vm.startDate, isNull);
        expect(vm.endDate, isNull);
        expect(vm.useDaysText, '0');
      });
    }

    test('사유 입력 필요 여부는 연차/반차만 false다', () {
      final vm = buildVm();
      const needsReasonTypes = [
        LeaveType.alternative,
        LeaveType.parental,
        LeaveType.family,
        LeaveType.other,
      ];

      for (final type in [LeaveType.full, ...halfUnitTypes]) {
        expect(vm.setLeaveType(type), isFalse, reason: type.label);
        expect(vm.needsReason, isFalse, reason: type.label);
      }
      for (final type in needsReasonTypes) {
        expect(vm.setLeaveType(type), isTrue, reason: type.label);
        expect(vm.needsReason, isTrue, reason: type.label);
      }
    });

    test('사유는 공백만 입력하면 null로 취급된다', () {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.other);

      vm.reasonController.text = '   ';
      expect(vm.leaveReason, isNull);

      vm.reasonController.text = '  경조사  ';
      expect(vm.leaveReason, '경조사');
    });
  });

  group('hasOverlapForSelection - 중복 검증', () {
    test('같은 시간대 반차가 있으면 중복이다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
            leaveType: 'AM_HALF', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(await vm.hasOverlapForSelection(), isTrue);
    });

    test('같은 날 다른 시간대 반차는 중복이 아니다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
            leaveType: 'AM_HALF', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.pmHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(await vm.hasOverlapForSelection(), isFalse);
    });

    test('종일 신청이 있는 날의 반차는 중복이다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'APPROVED', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.pmHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(await vm.hasOverlapForSelection(), isTrue);
    });

    test('반려/취소된 신청은 중복 판정에서 제외된다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'REJECTED', startDate: '2026-08-10'),
        existing(
            leaveType: 'FULL', status: 'CANCELLED', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(await vm.hasOverlapForSelection(), isFalse);
    });

    test('refresh를 지정하면 목록을 다시 조회한 뒤 판정한다', () async {
      final vm = buildVm();
      await vm.load();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      await vm.hasOverlapForSelection(refresh: true);

      expect(fake.myLeaveRequestQueries, hasLength(2));
    });
  });

  group('exceedsRemaining - 잔여 연차 검증', () {
    test('사용 일수가 잔여 연차를 초과할 때만 true다', () {
      final vm = buildVm(); // 잔여 11.5일
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 11), DateTime(2026, 8, 11));

      expect(vm.useDaysText, '2');
      expect(vm.exceedsRemaining(), isFalse);
    });

    test('잔여 연차가 부족하면 true다', () {
      fakeAuth = FakeAuthSession(
        employeeInfo: Employee.fromJson(
            fixtureJson('admin/employee.json')..['remainingLeaveDays'] = 0.0),
      );
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.exceedsRemaining(), isTrue);
    });

    test('사용 일수가 잔여 연차와 정확히 같으면 통과한다', () {
      fakeAuth = FakeAuthSession(
        employeeInfo: Employee.fromJson(
            fixtureJson('admin/employee.json')..['remainingLeaveDays'] = 3.0),
      );
      final vm = buildVm();

      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 12));

      expect(vm.remainingLeaveDays, 3.0);
      expect(vm.useDays, 3.0);
      expect(vm.exceedsRemaining(), isFalse); // 경계값은 초과가 아니다
    });

    test('0.5일이라도 잔여 연차보다 많으면 초과다', () {
      fakeAuth = FakeAuthSession(
        employeeInfo: Employee.fromJson(
            fixtureJson('admin/employee.json')..['remainingLeaveDays'] = 0.5),
      );
      final vm = buildVm();
      vm.setLeaveType(LeaveType.pmHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.exceedsRemaining(), isFalse); // 0.5 == 0.5

      vm.setLeaveType(LeaveType.full);
      expect(vm.useDaysText, '1');
      expect(vm.exceedsRemaining(), isTrue); // 1 > 0.5
    });

    test('사원 정보가 없으면 잔여 연차가 0이라 모든 신청이 막힌다', () {
      fakeAuth = FakeAuthSession(); // employeeInfo == null
      final vm = buildVm();

      expect(vm.remainingLeaveDays, 0);

      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      expect(vm.exceedsRemaining(), isTrue);

      vm.setLeaveType(LeaveType.full);
      expect(vm.exceedsRemaining(), isTrue);
    });

    test('사용 일수가 0이면 잔여 연차가 0이어도 초과가 아니다', () {
      fakeAuth = FakeAuthSession(); // 잔여 0
      final vm = buildVm();

      selectRange(vm, DateTime(2026, 8, 8), DateTime(2026, 8, 9)); // 주말만

      expect(vm.useDays, 0.0);
      expect(vm.exceedsRemaining(), isFalse); // 0 > 0 이 아님
    });

    test('대체/출산/가족돌봄 휴가도 프론트에서는 잔여 연차로 막힌다 (백엔드와 불일치)', () {
      // 발견한 문제:
      // 백엔드 LeaveRequestService.createLeaveRequest는 ALTERNATIVE / PARENTAL /
      // FAMILY 를 validateRemainingLeave 대상에서 제외한다.
      // 반면 LVE001_M01_view_model.exceedsRemaining()은 휴가 종류를 보지 않고
      // useDays > remainingLeaveDays 만 판단하므로, 잔여 연차가 없는 사용자는
      // 서버에서 허용되는 이 3종도 화면에서 신청할 수 없다.
      // 현재 프론트 동작을 그대로 고정해 둔다.
      fakeAuth = FakeAuthSession(
        employeeInfo: Employee.fromJson(
            fixtureJson('admin/employee.json')..['remainingLeaveDays'] = 0.0),
      );

      for (final type in [
        LeaveType.alternative,
        LeaveType.parental,
        LeaveType.family,
      ]) {
        final vm = buildVm();
        vm.setLeaveType(type);
        selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));

        expect(vm.useDays, 2.0, reason: type.label);
        expect(vm.exceedsRemaining(), isTrue,
            reason: '${type.label}은 백엔드에서는 잔여 연차 검증 대상이 아니다');
      }
    });
  });

  group('submit - 신청 제출', () {
    test('성공 시 요청 본문이 정확하고 데이터 갱신과 폼 초기화가 수행된다', () async {
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.family);
      vm.reasonController.text = '가족 돌봄';
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 11), DateTime(2026, 8, 11));

      final ok = await vm.submit();

      expect(ok, isTrue);
      expect(fake.submittedRequests, hasLength(1));
      expect(fake.submittedRequests.single.toJson(), {
        'leaveType': 'FAMILY',
        'startDate': '2026-08-10',
        'endDate': '2026-08-11',
        'useDays': 2.0,
        'leaveReason': '가족 돌봄',
      });
      // 갱신: 내 정보 (load 1회 + 제출 후 1회), 목록 재조회
      expect(fakeAuth.fetchMyInfoCount, 2);
      expect(fake.myLeaveRequestQueries, hasLength(2));
      // 폼 초기화
      expect(vm.startDate, isNull);
      expect(vm.endDate, isNull);
      expect(vm.useDaysText, '0');
      expect(vm.selectedLeaveType, LeaveType.full);
      expect(vm.reasonController.text, isEmpty);
    });

    test('실패 시 오류 메시지를 세팅하고 폼을 유지한다', () async {
      fake.submitErrorToThrow = Exception('network');
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));
      vm.selectDay(DateTime(2026, 8, 11), DateTime(2026, 8, 11));

      final ok = await vm.submit();

      expect(ok, isFalse);
      expect(vm.errorMessage, '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.');
      expect(vm.startDate, isNotNull);
      expect(vm.isSubmitting, isFalse);
    });

    for (final type in [
      LeaveType.full,
      LeaveType.alternative,
      LeaveType.parental,
      LeaveType.family,
      LeaveType.other,
    ]) {
      test('${type.label} 신청 본문에 코드 ${type.code}와 계산된 일수가 담긴다', () async {
        final vm = buildVm();
        vm.setLeaveType(type);
        vm.reasonController.text = '사유 ${type.label}';
        selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));

        expect(await vm.submit(), isTrue);
        expect(fake.submittedRequests.single.toJson(), {
          'leaveType': type.code,
          'startDate': '2026-08-10',
          'endDate': '2026-08-11',
          'useDays': 2.0,
          // 연차는 사유 입력란이 없지만 VM은 입력값이 있으면 그대로 담는다.
          'leaveReason': '사유 ${type.label}',
        });
      });
    }

    for (final type in [LeaveType.amHalf, LeaveType.pmHalf]) {
      test('${type.label} 신청 본문에 코드 ${type.code}와 0.5일이 담긴다', () async {
        final vm = buildVm();
        vm.setLeaveType(type);
        vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

        expect(await vm.submit(), isTrue);
        expect(fake.submittedRequests.single.toJson(), {
          'leaveType': type.code,
          'startDate': '2026-08-10',
          'endDate': '2026-08-10',
          'useDays': 0.5,
          'leaveReason': null,
        });
      });
    }

    test('사유를 비워 두면 leaveReason이 null로 전송된다', () async {
      final vm = buildVm();
      vm.setLeaveType(LeaveType.other);
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));

      // 발견한 문제: 사유가 필수인 종류인데도 VM은 빈 사유를 그대로 제출한다.
      expect(await vm.submit(), isTrue);
      expect(fake.submittedRequests.single.leaveReason, isNull);
    });

    test('종료일이 없으면 시작일이 종료일로 채워진다', () async {
      final vm = buildVm();
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10)); // 시작일만 선택

      expect(vm.endDate, isNull);
      // 발견한 문제: 이 상태의 useDays는 0이지만 VM은 제출을 막지 않는다.
      // (화면에서만 useDays <= 0 을 검사한다)
      expect(await vm.submit(), isTrue);
      expect(fake.submittedRequests.single.toJson(), {
        'leaveType': 'FULL',
        'startDate': '2026-08-10',
        'endDate': '2026-08-10',
        'useDays': 0.0,
        'leaveReason': null,
      });
    });

    test('제출 성공 후 갱신이 실패해도 true를 돌려주고 폼을 초기화한다', () async {
      final vm = buildVm();
      await vm.load();
      vm.setLeaveType(LeaveType.family);
      vm.reasonController.text = '가족 돌봄';
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));
      // 제출은 성공하고 이후 목록 재조회만 실패하도록 만든다.
      fake.errorToThrow = Exception('목록 조회 실패');

      final ok = await vm.submit();

      expect(ok, isTrue);
      expect(fake.submittedRequests, hasLength(1));
      expect(vm.startDate, isNull);
      expect(vm.endDate, isNull);
      expect(vm.useDaysText, '0');
      expect(vm.selectedLeaveType, LeaveType.full);
      expect(vm.reasonController.text, isEmpty);
      expect(vm.errorMessage, isNull);
    });

    test('제출 중에는 isSubmitting이 true로 알려지고 끝나면 false로 돌아온다', () async {
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));
      final notified = <bool>[];
      vm.addListener(() => notified.add(vm.isSubmitting));

      await vm.submit();

      expect(notified.first, isTrue); // 제출 시작 알림
      expect(notified.last, isFalse);
      expect(vm.isSubmitting, isFalse);
    });

    test('VM은 연속 제출을 막지 않는다 (중복 방지는 화면 버튼 비활성화에 의존)', () async {
      // 발견한 문제: submit()은 _isSubmitting을 세우기만 하고 진입 시 검사하지 않는다.
      // 화면에서 버튼을 비활성화하는 것으로만 중복 제출을 막고 있다.
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));

      final results = await Future.wait([vm.submit(), vm.submit()]);

      expect(results, [true, true]);
      expect(fake.submittedRequests, hasLength(2));
    });

    test('제출 실패 후 다시 제출하면 이전 오류 메시지가 지워진다', () async {
      fake.submitErrorToThrow = Exception('network');
      final vm = buildVm();
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));
      await vm.submit();
      expect(vm.errorMessage, isNotNull);

      fake.submitErrorToThrow = null;
      final ok = await vm.submit();

      expect(ok, isTrue);
      expect(vm.errorMessage, isNull);
    });
  });

  group('halfDayStatus - 캘린더 별표 상태', () {
    test('신청이 없으면 오전/오후 모두 비어 있다', () async {
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, isNull);
      expect(status.pmStatus, isNull);
    });

    test('오전 반차만 있으면 오전만 점유한다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
            leaveType: 'AM_HALF', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, 'PENDING');
      expect(status.pmStatus, isNull);
    });

    test('오후 반차만 있으면 오후만 점유한다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
            leaveType: 'PM_HALF', status: 'APPROVED', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, isNull);
      expect(status.pmStatus, 'APPROVED');
    });

    test('종일 신청은 오전과 오후를 모두 점유한다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'APPROVED', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, 'APPROVED');
      expect(status.pmStatus, 'APPROVED');
    });

    for (final type in [
      LeaveType.alternative,
      LeaveType.parental,
      LeaveType.family,
      LeaveType.other,
    ]) {
      test('${type.label}도 종일로 오전/오후를 모두 점유한다', () async {
        fake.myLeaveRequestsToReturn = [
          existing(
              leaveType: type.code, status: 'PENDING', startDate: '2026-08-10'),
        ];
        final vm = buildVm();
        await vm.load();

        final status = vm.halfDayStatus(DateTime(2026, 8, 10));

        expect(status.amStatus, 'PENDING');
        expect(status.pmStatus, 'PENDING');
      });
    }

    test('같은 날 오전/오후 반차가 각각 있으면 둘 다 점유한다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
            leaveType: 'AM_HALF', status: 'APPROVED', startDate: '2026-08-10'),
        existing(
            leaveType: 'PM_HALF', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, 'APPROVED');
      expect(status.pmStatus, 'PENDING');
    });

    test('다일 기간 신청은 기간 안의 모든 날짜를 점유하고 기간 밖은 비어 있다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(
          leaveType: 'FULL',
          status: 'PENDING',
          startDate: '2026-08-10',
          endDate: '2026-08-12',
        ),
      ];
      final vm = buildVm();
      await vm.load();

      for (final day in [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
      ]) {
        final status = vm.halfDayStatus(day);
        expect(status.amStatus, 'PENDING', reason: '$day');
        expect(status.pmStatus, 'PENDING', reason: '$day');
      }

      expect(vm.halfDayStatus(DateTime(2026, 8, 9)).amStatus, isNull);
      expect(vm.halfDayStatus(DateTime(2026, 8, 13)).amStatus, isNull);
    });

    test('시각 정보가 붙은 날짜도 같은 날로 판정한다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10, 23, 59, 59));

      expect(status.amStatus, 'PENDING');
    });

    test('반려/취소된 신청은 별표 상태에 반영되지 않는다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'REJECTED', startDate: '2026-08-10'),
        existing(
            leaveType: 'AM_HALF', status: 'CANCELLED', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, isNull);
      expect(status.pmStatus, isNull);
    });

    test('반려된 신청과 대기 신청이 겹치면 대기 상태만 남는다', () async {
      fake.myLeaveRequestsToReturn = [
        existing(leaveType: 'FULL', status: 'REJECTED', startDate: '2026-08-10'),
        existing(
            leaveType: 'PM_HALF', status: 'PENDING', startDate: '2026-08-10'),
      ];
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, isNull);
      expect(status.pmStatus, 'PENDING');
    });

    test('목록 조회가 실패하면 별표 상태가 비어 있다', () async {
      fake.errorToThrow = Exception('목록 조회 실패');
      final vm = buildVm();
      await vm.load();

      final status = vm.halfDayStatus(DateTime(2026, 8, 10));

      expect(status.amStatus, isNull);
      expect(status.pmStatus, isNull);
    });

    test('제출에 성공하면 갱신된 목록이 별표 상태에 반영된다', () async {
      final vm = buildVm();
      await vm.load();
      expect(vm.halfDayStatus(DateTime(2026, 8, 10)).amStatus, isNull);

      fake.myLeaveRequestsToReturn = [
        existing(
          leaveType: 'FULL',
          status: 'PENDING',
          startDate: '2026-08-10',
          endDate: '2026-08-11',
        ),
      ];
      selectRange(vm, DateTime(2026, 8, 10), DateTime(2026, 8, 11));
      await vm.submit();

      expect(vm.halfDayStatus(DateTime(2026, 8, 11)).pmStatus, 'PENDING');
    });
  });
}
