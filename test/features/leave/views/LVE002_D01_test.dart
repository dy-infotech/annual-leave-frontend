import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_D01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

/// 휴가 신청 상세 화면(LVE002_D01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeLeaveRepository fake;

  setUp(() {
    fake = FakeLeaveRepository();
  });

  Future<void> pumpDetailScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      LeaveRequestDetailScreen(requestId: 11, repository: fake),
    );
    await pumpUntilFound(tester, find.text('휴가자'));
  }

  testWidgets('조회 - 휴가자, 신청 내역, 결재 내역이 표시된다', (tester) async {
    fake.detailToReturn = LeaveRequestDetail.fromJson(
        fixtureJson('leave/leave_request_detail.json'));

    await pumpDetailScreen(tester);

    expect(find.text('휴가 신청 상세 정보'), findsOneWidget);
    expect(fake.fetchedDetailIds, [11]);

    // 휴가자
    expect(find.text('A0001'), findsOneWidget);
    expect(find.text('홍길동 과장'), findsOneWidget);

    // 신청 내역
    expect(find.text('반차(오전)'), findsOneWidget);
    expect(find.text('2026.08.10 ~ 2026.08.10'), findsOneWidget);
    expect(find.text('0.5일'), findsOneWidget);
    expect(find.text('개인 사유'), findsOneWidget);
    expect(find.text('2026.08.01'), findsOneWidget);
    expect(find.text('승인'), findsOneWidget);

    // 결재 내역 (뷰포트 아래에 있어 스크롤 후 확인)
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('A0002'), findsOneWidget);
    expect(find.text('김결재 부장'), findsOneWidget);
    expect(find.text('2026.08.02'), findsOneWidget);
  });

  testWidgets('결재자 미배정 - 안내 문구가 표시되고 사유 없음은 -로 표시된다', (tester) async {
    final json = fixtureJson('leave/leave_request_detail.json')
      ..remove('approverNumber')
      ..remove('approverName')
      ..remove('approverPosition')
      ..remove('approverDepartment')
      ..remove('managedAt')
      ..remove('leaveReason')
      ..['status'] = 'PENDING';
    fake.detailToReturn = LeaveRequestDetail.fromJson(json);

    await pumpDetailScreen(tester);

    expect(find.text('-'), findsOneWidget); // 신청 사유
    expect(find.text('대기'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('아직 승인되지 않은 요청입니다.'), findsOneWidget);
  });

  testWidgets('조회 실패 - 오류 메시지가 표시된다', (tester) async {
    fake.errorToThrow = Exception('network');

    await pumpApp(
      tester,
      LeaveRequestDetailScreen(requestId: 11, repository: fake),
    );
    await pumpUntilFound(tester, find.text('상세 정보를 불러오지 못했습니다.'));

    expect(find.text('상세 정보를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('휴가자'), findsNothing);
  });
}
