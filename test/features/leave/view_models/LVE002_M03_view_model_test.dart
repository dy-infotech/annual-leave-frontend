import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_M03_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

void main() {
  late FakeLeaveRepository fake;
  late FakeCommonCodeRepository fakeCodes;

  setUp(() {
    fake = FakeLeaveRepository();
    fakeCodes = FakeCommonCodeRepository();
    fake.adminSearchResultsToReturn = [
      LeaveRequestListItem.fromJson(
          fixtureJson('leave/leave_request_list_item.json')),
    ];
  });

  List<LeaveRequestListItem> pageItems(int startId, int count) =>
      List.generate(count, (index) {
        final json = fixtureJson('leave/leave_request_list_item.json');
        json['requestId'] = startId + index;
        return LeaveRequestListItem.fromJson(json);
      });

  AdminSearchLeaveRequestsViewModel buildVm(
          {String filter = 'admin_approved'}) =>
      AdminSearchLeaveRequestsViewModel(
        initialFilter: filter,
        repository: fake,
        commonCodeRepository: fakeCodes,
      );

  group('AdminSearchLeaveRequestsViewModel', () {
    test('load - 승인 필터면 approved 상태로 조회하고 팀 목록을 채운다', () async {
      final vm = buildVm();

      await vm.load();
      await Future<void>.delayed(Duration.zero);

      expect(vm.status, 'approved');
      expect(vm.statusName, '승인');
      expect(vm.items, hasLength(1));
      expect(vm.teamList, ['전체', 'SI사업팀', 'BI사업팀']);
      expect(
        fake.adminSearchQueries.every((q) => q['status'] == 'approved'),
        isTrue,
      );
    });

    test('load - 반려 필터면 rejected 상태로 조회한다', () async {
      final vm = buildVm(filter: 'admin_rejected');

      await vm.load();

      expect(vm.status, 'rejected');
      expect(vm.statusName, '반려');
    });

    test('접근 가능 팀이 비어 있어도 전체 선택은 정상 제공한다', () async {
      fakeCodes.codesToReturn = {'accessibleTeam': []};
      final vm = buildVm();

      await vm.getComData();

      expect(vm.errorMessage, isNull);
      expect(vm.teamList, ['전체']);
    });

    test('setFilter - 전달된 상태값을 정규화해 재조회한다', () async {
      final vm = buildVm();
      await vm.load();

      vm.setFilter('REJECTED');
      await Future<void>.delayed(Duration.zero);

      expect(vm.status, 'rejected');
      expect(fake.adminSearchQueries.last['status'], 'rejected');
    });

    test('selectTeam - 팀 선택 시 해당 팀으로, 전체 선택 시 null로 조회한다', () async {
      final vm = buildVm();
      await vm.load();

      vm.selectTeam('SI사업팀');
      await Future<void>.delayed(Duration.zero);
      expect(fake.adminSearchQueries.last['team'], 'SI사업팀');

      vm.selectTeam('전체');
      await Future<void>.delayed(Duration.zero);
      expect(fake.adminSearchQueries.last['team'], isNull);
    });

    test('검색어가 있으면 employeeParam으로, 비어 있으면 null로 조회한다', () async {
      final vm = buildVm();
      await vm.load();

      vm.searchEmployeeController.text = '홍길동';
      await vm.fetch();
      expect(fake.adminSearchQueries.last['employeeParam'], '홍길동');

      vm.searchEmployeeController.text = '';
      await vm.fetch();
      expect(fake.adminSearchQueries.last['employeeParam'], isNull);
    });

    test('loadMore - 다음 페이지를 이어 붙이고 조회 시점 검색어를 유지한다', () async {
      fake.adminSearchResultsByPage[0] = pageItems(1, 50);
      fake.adminSearchResultsByPage[1] = pageItems(51, 1);
      final vm = buildVm();

      vm.searchEmployeeController.text = '홍길동';
      await vm.load();

      expect(vm.items, hasLength(50));
      expect(vm.hasMore, isTrue);
      expect(fake.adminSearchPageRequests.first, {'page': 0, 'size': 50});
      expect(fake.adminSearchQueries.first['employeeParam'], '홍길동');

      // 입력만 바꾸고 조회하지 않은 값은 현재 무한스크롤 세션에 섞이면 안 된다.
      vm.searchEmployeeController.text = '김철수';
      await vm.loadMore();

      expect(vm.items, hasLength(51));
      expect(vm.hasMore, isFalse);
      expect(fake.adminSearchPageRequests.last, {'page': 1, 'size': 50});
      expect(fake.adminSearchQueries.last['employeeParam'], '홍길동');
    });

    test('fetch 실패 - 오류 메시지가 세팅되고 로딩이 끝난다', () async {
      fake.errorToThrow = Exception('network');
      final vm = buildVm();

      await vm.fetch();

      expect(vm.errorMessage, '목록을 불러오지 못했습니다.');
      expect(vm.isLoading, isFalse);
    });
  });
}
