import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M01.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

/// 내 휴가 신청 목록 화면(LVE002_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
  });

  LeaveRequestListItem item({
    int requestId = 11,
    String status = 'PENDING',
    String? rejectReason,
  }) {
    final json = fixtureJson('leave/leave_request_list_item.json')
      ..['requestId'] = requestId
      ..['status'] = status
      ..['rejectReason'] = rejectReason;
    return LeaveRequestListItem.fromJson(json);
  }

  Future<void> pumpListScreen(WidgetTester tester) async {
    await pumpApp(tester, MyLeaveRequestsScreen(repository: fake));
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 목록 카드에 기간, 일수, 상태 배지가 표시된다', (tester) async {
    fake.myLeaveRequestsToReturn = [
      item(requestId: 11, status: 'PENDING'),
      item(requestId: 12, status: 'APPROVED'),
    ];

    await pumpListScreen(tester);

    expect(find.text('내 신청 목록'), findsOneWidget);
    expect(find.text('2026-08-10 — 2026-08-11'), findsNWidgets(2));
    expect(find.text('2.0일'), findsNWidgets(2));
    expect(find.text('대기'), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);
    // 초기 조회는 조건 없이 1회
    expect(fake.myLeaveRequestQueries, [
      {'status': null, 'startDate': null, 'endDate': null},
    ]);
  });

  testWidgets('조회 - 내역이 없으면 안내 문구가 표시된다', (tester) async {
    await pumpListScreen(tester);

    expect(find.text('신청 내역이 없습니다.'), findsOneWidget);
  });

  testWidgets('상태 필터 - 드롭다운에서 선택하면 해당 상태로 재조회한다', (tester) async {
    await pumpListScreen(tester);

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대기').last);
    await tester.pumpAndSettle();

    expect(fake.myLeaveRequestQueries.last,
        {'status': 'PENDING', 'startDate': null, 'endDate': null});
  });

  testWidgets('반려 항목 - 반려 사유가 표시되고 취소 버튼이 없다', (tester) async {
    fake.myLeaveRequestsToReturn = [
      item(status: 'REJECTED', rejectReason: '일정 조율 필요'),
    ];

    await pumpListScreen(tester);

    expect(find.text('반려 사유'), findsOneWidget);
    expect(find.text('일정 조율 필요'), findsOneWidget);
    expect(find.text('신청 취소'), findsNothing);
  });

  testWidgets('신청 취소 - 확인 다이얼로그를 거쳐 취소되고 목록을 재조회한다', (tester) async {
    fake.myLeaveRequestsToReturn = [item(requestId: 11, status: 'PENDING')];

    await pumpListScreen(tester);

    await tester.tap(find.text('신청 취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('신청을 취소하시겠습니까?'), findsOneWidget);

    await tester.tap(find.text('취소하기'));
    await tester.pumpAndSettle();

    expect(fake.cancelledIds, [11]);
    expect(find.text('신청이 취소되었습니다.'), findsOneWidget);
    expect(fake.myLeaveRequestQueries, hasLength(2)); // 초기 조회 + 취소 후 재조회
  });

  testWidgets('신청 취소 - 아니오를 누르면 취소 API를 호출하지 않는다', (tester) async {
    fake.myLeaveRequestsToReturn = [item(requestId: 11, status: 'PENDING')];

    await pumpListScreen(tester);

    await tester.tap(find.text('신청 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();

    expect(fake.cancelledIds, isEmpty);
  });

  testWidgets('신청 취소 실패 - 실패 안내가 표시된다', (tester) async {
    fake.myLeaveRequestsToReturn = [item(requestId: 11, status: 'PENDING')];
    fake.cancelErrorToThrow = Exception('network');

    await pumpListScreen(tester);

    await tester.tap(find.text('신청 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소하기'));
    await tester.pumpAndSettle();

    expect(find.text('취소 처리에 실패했습니다.'), findsOneWidget);
  });
}
