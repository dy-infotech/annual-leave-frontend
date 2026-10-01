import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_M02_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';


class _PagedAllLeaveRepository extends FakeLeaveRepository {
  _PagedAllLeaveRepository(this.pages);

  final List<PageResult<LeaveRequestListItem>> pages;
  int _index = 0;

  @override
  Future<PageResult<LeaveRequestListItem>> fetchAllLeaveRequestsPage({
    String? status,
    String? startDate,
    String? endDate,
    int page = 0,
    int size = LeaveRepository.defaultPageSize,
    String? cursorRequestedAt,
    int? cursorRequestId,
  }) async {
    allLeaveRequestQueries
        .add({'status': status, 'startDate': startDate, 'endDate': endDate});
    final current = pages[_index];
    if (_index < pages.length - 1) {
      _index++;
    }
    return current;
  }
}

void main() {
  late FakeLeaveRepository fake;

  final year = DateTime.now().year;
  final yearStart = '$year-01-01';
  final yearEnd = '$year-12-31';

  setUp(() {
    fake = FakeLeaveRepository();
    fake.allLeaveRequestsToReturn = [
      LeaveRequestListItem.fromJson(
          fixtureJson('leave/leave_request_list_item.json')),
    ];
  });

  group('AllLeaveRequestsViewModel', () {
    test('load - 전체 API를 당해년도 조건으로 조회한다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);

      await vm.load();

      expect(fake.allLeaveRequestQueries, [
        {'status': null, 'startDate': yearStart, 'endDate': yearEnd},
      ]);
      expect(fake.myLeaveRequestQueries, isEmpty);
      expect(vm.items, hasLength(1));
      expect(vm.isLoading, isFalse);
    });

    test('load - 전체 권한이 없으면 all 초기값도 내 신청으로 강제한다', () async {
      final vm = AllLeaveRequestsViewModel(
        initialFilter: 'all',
        canViewAll: false,
        repository: fake,
      );

      await vm.load();

      expect(vm.buttonLabel, '내 신청');
      expect(fake.allLeaveRequestQueries, isEmpty);
      expect(fake.myLeaveRequestQueries, [
        {'status': null, 'startDate': yearStart, 'endDate': yearEnd},
      ]);

      vm.setButtonLabel('전체');
      await Future<void>.delayed(Duration.zero);
      expect(vm.buttonLabel, '내 신청');
      expect(fake.allLeaveRequestQueries, isEmpty);
    });

    test('load - 초기 필터가 my면 내 신청 라벨로 my API를 조회한다', () async {
      final vm = AllLeaveRequestsViewModel(
          initialStatus: 'PENDING', initialFilter: 'my', repository: fake);

      await vm.load();

      expect(vm.buttonLabel, '내 신청');
      expect(vm.statusFilter, 'PENDING');
      expect(fake.myLeaveRequestQueries, isNotEmpty);
      expect(
        fake.myLeaveRequestQueries.every((q) => q['status'] == 'PENDING'),
        isTrue,
      );
    });

    test('setButtonLabel - 내 신청으로 바꾸면 상태 필터를 유지하며 my API로 재조회한다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();
      vm.setFilter('APPROVED');
      await Future<void>.delayed(Duration.zero);

      vm.setButtonLabel('내 신청');
      await Future<void>.delayed(Duration.zero);

      expect(fake.myLeaveRequestQueries.last,
          {'status': 'APPROVED', 'startDate': yearStart, 'endDate': yearEnd});
    });

    test('setDateRange - 기간이 바뀐 경우에만 재조회한다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();

      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      );
      vm.setDateRange(range);
      await Future<void>.delayed(Duration.zero);

      expect(fake.allLeaveRequestQueries.last, {
        'status': null,
        'startDate': '2026-03-01',
        'endDate': '2026-03-31',
      });

      final callCount = fake.allLeaveRequestQueries.length;
      vm.setDateRange(range); // 같은 기간 재선택
      await Future<void>.delayed(Duration.zero);
      expect(fake.allLeaveRequestQueries, hasLength(callCount));
    });

    test('clearDateRange - 당해년도 기본 조건으로 되돌아간다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();
      vm.setDateRange(DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 31),
      ));
      await Future<void>.delayed(Duration.zero);

      vm.clearDateRange();
      await Future<void>.delayed(Duration.zero);

      expect(fake.allLeaveRequestQueries.last,
          {'status': null, 'startDate': yearStart, 'endDate': yearEnd});
    });

    test('무한스크롤은 200건을 넘어서도 서버 hasMore가 true면 계속 조회한다', () async {
      List<LeaveRequestListItem> pageItems(int startId, int count) =>
          List.generate(count, (index) {
            final json = fixtureJson('leave/leave_request_list_item.json');
            json['requestId'] = startId + index;
            json['requestedAt'] =
                '2026-09-${((startId + index) % 28 + 1).toString().padLeft(2, '0')}T09:00:00';
            return LeaveRequestListItem.fromJson(json);
          });

      final paged = _PagedAllLeaveRepository([
        PageResult(items: pageItems(1, 50), totalCount: 201, hasMore: true),
        PageResult(items: pageItems(51, 50), totalCount: 201, hasMore: true),
        PageResult(items: pageItems(101, 50), totalCount: 201, hasMore: true),
        PageResult(items: pageItems(151, 50), totalCount: 201, hasMore: true),
        PageResult(items: pageItems(201, 1), totalCount: 201, hasMore: false),
      ]);
      final vm = AllLeaveRequestsViewModel(repository: paged);

      await vm.load();
      await vm.loadMore();
      await vm.loadMore();
      await vm.loadMore();

      expect(vm.items, hasLength(200));
      expect(vm.totalCount, 201);
      expect(vm.hasMore, isTrue);

      await vm.loadMore();

      expect(vm.items, hasLength(201));
      expect(vm.totalCount, 201);
      expect(vm.hasMore, isFalse);
      expect(paged.allLeaveRequestQueries, hasLength(5));
    });

    test('cancel 성공 - true를 돌려주고 재조회한다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();

      final ok = await vm.cancel(11);

      expect(ok, isTrue);
      expect(fake.cancelledIds, [11]);
      expect(fake.allLeaveRequestQueries, hasLength(2));
    });

    test('isCancelable - 본인의 대기 또는 미래 승인 건만 취소할 수 있다', () {
      LeaveRequestListItem item(String status, String startDate) =>
          LeaveRequestListItem.fromJson(
              fixtureJson('leave/leave_request_list_item.json')
                ..['status'] = status
                ..['startDate'] = startDate
                ..['endDate'] = startDate);
      final now = DateTime(2026, 9, 30);

      expect(AllLeaveRequestsViewModel.isCancelable(
          item('PENDING', '2026-09-01'), 'A0001', now: now), isTrue);
      expect(AllLeaveRequestsViewModel.isCancelable(
          item('APPROVED', '2026-10-01'), 'A0001', now: now), isTrue);
      expect(AllLeaveRequestsViewModel.isCancelable(
          item('APPROVED', '2026-10-01'), 'B0002', now: now), isFalse);
      expect(AllLeaveRequestsViewModel.isCancelable(
          item('APPROVED', '2026-09-30'), 'A0001', now: now), isFalse);
    });

    test('조회 실패 - 예외를 잡지 않고 그대로 전파한다', () async {
      // fetch에는 catch가 없어 오류 메시지를 남기지 못하고 예외가 올라온다.
      // 화면에 실패를 알릴 수단이 없는 상태를 기록해 둔다.
      fake.errorToThrow = Exception('network');
      final vm = AllLeaveRequestsViewModel(repository: fake);

      await expectLater(vm.load(), throwsA(isA<Exception>()));
      expect(vm.items, isEmpty);
      expect(vm.isLoading, isFalse); // finally로 로딩 상태는 해제된다
    });

    test('조회 실패 후 다시 조회에 성공하면 목록이 채워진다', () async {
      fake.errorToThrow = Exception('network');
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await expectLater(vm.load(), throwsA(isA<Exception>()));

      fake.errorToThrow = null;
      await vm.fetch();

      expect(vm.items, isNotEmpty);
    });
  });
}
