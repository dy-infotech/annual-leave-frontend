import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE003_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

/// 결재 대기 목록 화면(LVE003_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
  });

  PendingLeaveRequest pending({int requestId = 21}) {
    final json = fixtureJson('leave/pending_leave_request.json')
      ..['requestId'] = requestId;
    return PendingLeaveRequest.fromJson(json);
  }

  Future<void> pumpPendingScreen(WidgetTester tester) async {
    await pumpApp(tester, PendingApprovalScreen(repository: fake));
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 신청자, 기간, 종류, 신청일, 건수가 표시된다', (tester) async {
    fake.pendingRequestsToReturn = [pending()];

    await pumpPendingScreen(tester);

    expect(find.text('결재 대기 목록'), findsOneWidget);
    expect(find.text('1건'), findsOneWidget);
    expect(find.text('이신청 대리'), findsOneWidget);
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('2026.09.01 ~ 2026.09.02'), findsOneWidget);
    expect(find.text('(2.0일) [연차]'), findsOneWidget);
    expect(find.text('신청일 : 2026.08.20'), findsOneWidget);
  });

  testWidgets('조회 - 대기 건이 없으면 안내 문구가 표시되고 하단 버튼이 없다', (tester) async {
    await pumpPendingScreen(tester);

    expect(find.text('대기 중인 휴가 신청이 없습니다.'), findsOneWidget);
    expect(find.text('승인'), findsNothing);
    expect(find.text('반려'), findsNothing);
  });

  testWidgets('조회 실패 - 오류 메시지가 표시된다', (tester) async {
    fake.errorToThrow = Exception('network');

    await pumpPendingScreen(tester);

    expect(find.text('목록을 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('선택 전 - 하단 승인/반려 버튼이 비활성화된다', (tester) async {
    fake.pendingRequestsToReturn = [pending()];

    await pumpPendingScreen(tester);

    final approveButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, '승인'));
    final rejectButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '반려'));
    expect(approveButton.onPressed, isNull);
    expect(rejectButton.onPressed, isNull);
  });

  testWidgets('승인 - 카드 선택 후 확인 다이얼로그를 거쳐 승인되고 재조회한다', (tester) async {
    fake.pendingRequestsToReturn = [pending(requestId: 21)];

    await pumpPendingScreen(tester);

    await tester.tap(find.text('이신청 대리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '승인'));
    await tester.pumpAndSettle();
    expect(find.text('승인 확인'), findsOneWidget);
    expect(find.textContaining('승인하시겠습니까?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '승인'));
    await tester.pumpAndSettle();

    expect(fake.approvedIds, [21]);
    expect(find.text('승인 처리되었습니다.'), findsOneWidget);
    expect(fake.pendingFetchCount, 2); // 초기 조회 + 승인 후 재조회
  });

  testWidgets('반려 - 사유를 입력하면 사유와 함께 반려 처리된다', (tester) async {
    fake.pendingRequestsToReturn = [pending(requestId: 21)];

    await pumpPendingScreen(tester);

    await tester.tap(find.text('이신청 대리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '반려'));
    await tester.pumpAndSettle();
    expect(find.text('반려 확인'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '일정 겹침');
    await tester.tap(find.widgetWithText(TextButton, '반려'));
    await tester.pumpAndSettle();

    expect(fake.rejections, [
      {'requestId': '21', 'rejectReason': '일정 겹침'},
    ]);
    expect(find.text('반려 처리되었습니다.'), findsOneWidget);
  });

  testWidgets('반려 - 사유를 비우면 null로 전송된다', (tester) async {
    fake.pendingRequestsToReturn = [pending(requestId: 21)];

    await pumpPendingScreen(tester);

    await tester.tap(find.text('이신청 대리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '반려'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '반려'));
    await tester.pumpAndSettle();

    expect(fake.rejections, [
      {'requestId': '21', 'rejectReason': null},
    ]);
  });

  testWidgets('승인 실패 - 실패 안내가 표시된다', (tester) async {
    fake.pendingRequestsToReturn = [pending(requestId: 21)];
    fake.approveErrorToThrow = Exception('network');

    await pumpPendingScreen(tester);

    await tester.tap(find.text('이신청 대리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '승인'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '승인'));
    await tester.pumpAndSettle();

    expect(find.text('승인 처리에 실패했습니다.'), findsOneWidget);
  });
}
