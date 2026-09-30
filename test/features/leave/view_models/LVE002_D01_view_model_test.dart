import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_D01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
  });

  group('LeaveRequestDetailViewModel', () {
    test('load 성공 - 상세 정보가 세팅되고 로딩이 끝난다', () async {
      fake.detailToReturn = LeaveRequestDetail.fromJson(
          fixtureJson('leave/leave_request_detail.json'));
      final vm = LeaveRequestDetailViewModel(requestId: 11, repository: fake);

      expect(vm.isLoading, isTrue);
      await vm.load();

      expect(fake.fetchedDetailIds, [11]);
      expect(vm.detail?.employeeName, '홍길동');
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('load 실패 - 오류 메시지가 세팅되고 로딩이 끝난다', () async {
      fake.errorToThrow = Exception('network');
      final vm = LeaveRequestDetailViewModel(requestId: 11, repository: fake);

      await vm.load();

      expect(vm.detail, isNull);
      expect(vm.errorMessage, '상세 정보를 불러오지 못했습니다.');
      expect(vm.isLoading, isFalse);
    });
  });
}
