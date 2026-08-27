import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE003_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
    fake.pendingRequestsToReturn = [
      PendingLeaveRequest.fromJson(
          fixtureJson('leave/pending_leave_request.json')),
    ];
  });

  group('PendingApprovalViewModel', () {
    test('fetch 성공 - 목록이 세팅되고 선택 상태가 초기화된다', () async {
      final vm = PendingApprovalViewModel(repository: fake);

      await vm.fetch();
      vm.select(21);
      expect(vm.hasSelection, isTrue);

      await vm.fetch();

      expect(vm.requests, hasLength(1));
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
      expect(vm.selectedRequestId, isNull);
    });

    test('fetch 실패 - 오류 메시지가 세팅된다', () async {
      fake.errorToThrow = Exception('network');
      final vm = PendingApprovalViewModel(repository: fake);

      await vm.fetch();

      expect(vm.errorMessage, '목록을 불러오지 못했습니다.');
      expect(vm.isLoading, isFalse);
    });

    test('selectedRequest - 선택한 건의 객체를 돌려준다', () async {
      final vm = PendingApprovalViewModel(repository: fake);
      await vm.fetch();

      expect(vm.selectedRequest, isNull);
      vm.select(21);
      expect(vm.selectedRequest?.employeeName, '이신청');
    });

    test('approve 성공 - true를 돌려주고 재조회한다', () async {
      final vm = PendingApprovalViewModel(repository: fake);
      await vm.fetch();

      final ok = await vm.approve(21);

      expect(ok, isTrue);
      expect(fake.approvedIds, [21]);
      expect(fake.pendingFetchCount, 2);
      expect(vm.isProcessing, isFalse);
    });

    test('approve 실패 - false를 돌려주고 처리 중 상태를 해제한다', () async {
      fake.approveErrorToThrow = Exception('network');
      final vm = PendingApprovalViewModel(repository: fake);
      await vm.fetch();

      final ok = await vm.approve(21);

      expect(ok, isFalse);
      expect(vm.isProcessing, isFalse);
    });

    test('reject - 사유가 있으면 사유와 함께, 비어 있으면 null로 전송한다', () async {
      final vm = PendingApprovalViewModel(repository: fake);
      await vm.fetch();

      await vm.reject(21, '일정 겹침');
      expect(fake.rejections.last,
          {'requestId': '21', 'rejectReason': '일정 겹침'});

      await vm.reject(21, '');
      expect(fake.rejections.last, {'requestId': '21', 'rejectReason': null});
    });
  });
}
