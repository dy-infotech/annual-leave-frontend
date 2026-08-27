import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE001_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';
import '../../../helpers/test_doubles/fake_public_holiday_repository.dart';

void main() {
  late FakeLeaveRepository fake;
  late FakePublicHolidayRepository fakeHolidays;
  late FakeAuthProvider fakeAuth;

  setUp(() {
    fake = FakeLeaveRepository();
    fakeHolidays = FakePublicHolidayRepository();
    fakeAuth = FakeAuthProvider(
      employeeInfo: Employee.fromJson(fixtureJson('admin/employee.json')),
    );
  });

  LeaveRequestViewModel buildVm() => LeaveRequestViewModel(
        authProvider: fakeAuth,
        repository: fake,
        holidayRepository: fakeHolidays,
      );

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
      fakeAuth = FakeAuthProvider(
        employeeInfo: Employee.fromJson(
            fixtureJson('admin/employee.json')..['remainingLeaveDays'] = 0.0),
      );
      final vm = buildVm();
      vm.setLeaveType(LeaveType.amHalf);
      vm.selectDay(DateTime(2026, 8, 10), DateTime(2026, 8, 10));

      expect(vm.exceedsRemaining(), isTrue);
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
  });
}
