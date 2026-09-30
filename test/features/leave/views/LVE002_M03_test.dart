import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M03.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

/// 관리자 휴가 검색 화면(LVE002_M03) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeLeaveRepository fake;
  late FakeCommonCodeRepository fakeCodes;

  setUp(() {
    fake = FakeLeaveRepository();
    fakeCodes = FakeCommonCodeRepository();
  });

  Future<void> pumpSearchScreen(WidgetTester tester,
      {String filter = 'admin_approved'}) async {
    await pumpApp(
      tester,
      AdminSearchLeaveRequestsScreen(
        filter: filter,
        repository: fake,
        commonCodeRepository: fakeCodes,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 승인 필터면 approved 상태로 조회하고 카드를 표시한다', (tester) async {
    fake.adminSearchResultsToReturn = [
      LeaveRequestListItem.fromJson(
          fixtureJson('leave/leave_request_list_item.json')),
    ];

    await pumpSearchScreen(tester);

    expect(find.text('승인 목록'), findsOneWidget);
    expect(find.text('1건'), findsOneWidget);
    expect(find.text('홍길동 과장'), findsOneWidget);
    expect(find.text('경영지원부'), findsOneWidget);
    expect(find.text('2026.08.10 ~ 2026.08.11'), findsOneWidget);
    expect(find.text('(2.0일) [연차]'), findsOneWidget);
    expect(
      fake.adminSearchQueries.every((q) =>
          q['status'] == 'approved' &&
          q['team'] == null &&
          q['employeeParam'] == null),
      isTrue,
    );
    expect(fakeCodes.fetchCount, 1);
  });

  testWidgets('조회 - 반려 필터면 rejected 상태로 조회한다', (tester) async {
    await pumpSearchScreen(tester, filter: 'admin_rejected');

    expect(find.text('반려 목록'), findsOneWidget);
    expect(
      fake.adminSearchQueries.every((q) => q['status'] == 'rejected'),
      isTrue,
    );
  });

  testWidgets('조회 - 내역이 없으면 안내 문구와 0건이 표시된다', (tester) async {
    await pumpSearchScreen(tester);

    expect(find.text('조회된 내역이 없습니다.'), findsOneWidget);
    expect(find.text('0건'), findsOneWidget);
  });

  testWidgets('팀 필터 - 팀을 선택하면 해당 팀으로, 전체를 선택하면 null로 조회한다', (tester) async {
    await pumpSearchScreen(tester);

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SI사업팀').last);
    await tester.pumpAndSettle();

    expect(fake.adminSearchQueries.last['team'], 'SI사업팀');

    await tester.tap(find.text('SI사업팀'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체').last);
    await tester.pumpAndSettle();

    expect(fake.adminSearchQueries.last['team'], isNull);
  });

  testWidgets('사번/성명 검색 - 입력 후 검색 아이콘을 누르면 employeeParam으로 조회한다',
      (tester) async {
    await pumpSearchScreen(tester);

    await tester.enterText(find.byType(TextField), '홍길동');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(fake.adminSearchQueries.last['employeeParam'], '홍길동');
  });

  testWidgets('조회 실패 - 이후 성공 조회 전까지 목록이 비어 있다', (tester) async {
    fake.errorToThrow = Exception('network');

    await pumpSearchScreen(tester);

    expect(find.text('조회된 내역이 없습니다.'), findsOneWidget);
  });
}
