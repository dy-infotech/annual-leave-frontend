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

    test('연도가 바뀐 뒤 재조회하면 새 당해년도 조건을 사용한다', () async {
      var now = DateTime(2026, 12, 31);
      final vm = AllLeaveRequestsViewModel(
        repository: fake,
        now: () => now,
      );

      await vm.load();
      expect(fake.allLeaveRequestQueries.last, {
        'status': null,
        'startDate': '2026-01-01',
        'endDate': '2026-12-31',
      });

      now = DateTime(2027, 1, 1);
      await vm.fetch();

      expect(fake.allLeaveRequestQueries.last, {
        'status': null,
        'startDate': '2027-01-01',
        'endDate': '2027-12-31',
      });
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

      final result = await vm.cancel(11);

      expect(result, CancelResult.succeeded);
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

    test('조회 실패 - 기존 행을 비우고 오류 상태로 고정하며 loadMore를 막는다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();
      expect(vm.items, isNotEmpty);

      fake.errorToThrow = Exception('network');
      vm.setFilter('APPROVED');
      await Future<void>.delayed(Duration.zero);

      expect(vm.items, isEmpty);
      expect(vm.loadError, isNotNull);
      expect(vm.hasMore, isFalse);

      final callCount = fake.allLeaveRequestQueries.length;
      await vm.loadMore();
      expect(fake.allLeaveRequestQueries, hasLength(callCount));
    });

    test('조회 실패 후 다시 조회에 성공하면 오류를 지우고 새 조건 목록만 채운다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();

      fake.errorToThrow = Exception('network');
      vm.setFilter('APPROVED');
      await Future<void>.delayed(Duration.zero);

      fake.errorToThrow = null;
      await vm.fetch();

      expect(vm.loadError, isNull);
      expect(vm.items, isNotEmpty);
      expect(fake.allLeaveRequestQueries.last['status'], 'APPROVED');
    });

    test('취소 API 성공 후 재조회 실패는 취소 실패로 오인하지 않는다', () async {
      final vm = AllLeaveRequestsViewModel(repository: fake);
      await vm.load();

      fake.errorToThrow = Exception('refresh failed');
      final result = await vm.cancel(11);

      expect(result, CancelResult.succeededRefreshFailed);
      expect(fake.cancelledIds, [11]);
      expect(vm.loadError, isNotNull);
    });
  });
}
