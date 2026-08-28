import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_M01_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
    fake.myLeaveRequestsToReturn = [
      LeaveRequestListItem.fromJson(
          fixtureJson('leave/leave_request_list_item.json')),
    ];
  });

  group('MyLeaveRequestsViewModel', () {
    test('load - 조건 없이 1회 조회하고 목록을 세팅한다', () async {
      final vm = MyLeaveRequestsViewModel(repository: fake);

      await vm.load();

      expect(fake.myLeaveRequestQueries, [
        {'status': null, 'startDate': null, 'endDate': null},
      ]);
      expect(vm.items, hasLength(1));
      expect(vm.isLoading, isFalse);
    });

    test('load - 초기 상태가 지정되면 해당 상태로 조회한다', () async {
      final vm = MyLeaveRequestsViewModel(
          initialStatus: 'PENDING', repository: fake);

      await vm.load();

      expect(vm.statusFilter, 'PENDING');
      expect(
        fake.myLeaveRequestQueries.every((q) => q['status'] == 'PENDING'),
        isTrue,
      );
    });

    test('setFilter - 선택한 상태로 재조회한다', () async {
      final vm = MyLeaveRequestsViewModel(repository: fake);
      await vm.load();

      vm.setFilter('APPROVED');
      await Future<void>.delayed(Duration.zero);

      expect(fake.myLeaveRequestQueries.last,
          {'status': 'APPROVED', 'startDate': null, 'endDate': null});
    });

    test('setDateRange / clearDateRange - 기간 조건으로 재조회한다', () async {
      final vm = MyLeaveRequestsViewModel(repository: fake);
      await vm.load();

      vm.setDateRange(DateTimeRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      ));
      await Future<void>.delayed(Duration.zero);

      expect(fake.myLeaveRequestQueries.last, {
        'status': null,
        'startDate': '2026-08-01',
        'endDate': '2026-08-31',
      });

      vm.clearDateRange();
      await Future<void>.delayed(Duration.zero);

      expect(fake.myLeaveRequestQueries.last,
          {'status': null, 'startDate': null, 'endDate': null});
    });

    test('cancel 성공 - true를 돌려주고 목록을 재조회한다', () async {
      final vm = MyLeaveRequestsViewModel(repository: fake);
      await vm.load();

      final ok = await vm.cancel(11);

      expect(ok, isTrue);
      expect(fake.cancelledIds, [11]);
      expect(fake.myLeaveRequestQueries, hasLength(2));
      expect(vm.isProcessing(11), isFalse);
    });

    test('cancel 실패 - false를 돌려주고 처리 중 상태를 해제한다', () async {
      fake.cancelErrorToThrow = Exception('network');
      final vm = MyLeaveRequestsViewModel(repository: fake);
      await vm.load();

      final ok = await vm.cancel(11);

      expect(ok, isFalse);
      expect(vm.isProcessing(11), isFalse);
    });

    test('조회 실패 - 예외를 잡지 않고 그대로 전파한다', () async {
      // 현재 _fetch에는 catch가 없어 오류 메시지를 남기지 못하고 예외가 올라온다.
      // 화면에 실패를 알릴 수단이 없는 상태를 기록해 둔다.
      fake.errorToThrow = Exception('network');
      final vm = MyLeaveRequestsViewModel(repository: fake);

      await expectLater(vm.load(), throwsA(isA<Exception>()));
      expect(vm.items, isEmpty);
      expect(vm.isLoading, isFalse); // finally로 로딩 상태는 해제된다
    });

    test('조회 실패 후 다시 조회에 성공하면 목록이 채워진다', () async {
      fake.errorToThrow = Exception('network');
      final vm = MyLeaveRequestsViewModel(repository: fake);
      await expectLater(vm.load(), throwsA(isA<Exception>()));

      fake.errorToThrow = null;
      fake.myLeaveRequestsToReturn = [
        LeaveRequestListItem.fromJson(
            fixtureJson('leave/leave_request_list_item.json')),
      ];
      await vm.load();

      expect(vm.items, hasLength(1));
    });

    test('isCancelable - 대기 상태만 취소할 수 있다', () {
      LeaveRequestListItem withStatus(String status) =>
          LeaveRequestListItem.fromJson(
              fixtureJson('leave/leave_request_list_item.json')
                ..['status'] = status);

      expect(MyLeaveRequestsViewModel.isCancelable(withStatus('PENDING')),
          isTrue);
      expect(MyLeaveRequestsViewModel.isCancelable(withStatus('APPROVED')),
          isFalse);
      expect(MyLeaveRequestsViewModel.isCancelable(withStatus('REJECTED')),
          isFalse);
    });
  });
}
