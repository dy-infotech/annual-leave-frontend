import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M02.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_provider.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';

/// 전직원 휴가 신청 목록 화면(LVE002_M02) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeLeaveRepository fake;

  final year = DateTime.now().year;
  final yearStart = '$year-01-01';
  final yearEnd = '$year-12-31';

  setUp(() {
    fake = FakeLeaveRepository();
  });

  LeaveRequestListItem item({
    int requestId = 11,
    String status = 'PENDING',
    String employeeNumber = 'A0001',
  }) {
    final json = fixtureJson('leave/leave_request_list_item.json')
      ..['requestId'] = requestId
      ..['status'] = status
      ..['employeeNumber'] = employeeNumber;
    return LeaveRequestListItem.fromJson(json);
  }

  Future<void> pumpAllListScreen(WidgetTester tester,
      {Employee? loginUser}) async {
    await pumpApp(
      tester,
      AllLeaveRequestsScreen(repository: fake),
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => FakeAuthProvider(employeeInfo: loginUser)),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 전체 목록을 당해년도 조건으로 조회해 카드로 표시한다', (tester) async {
    fake.allLeaveRequestsToReturn = [item()];

    await pumpAllListScreen(tester);

    expect(find.text('신청 목록'), findsOneWidget);
    expect(find.text('1건'), findsOneWidget);
    expect(find.text('홍길동 과장'), findsOneWidget);
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('2026.08.10 ~ 2026.08.11'), findsOneWidget);
    expect(find.text('(2.0일) [연차]'), findsOneWidget);
    expect(find.text('신청일 : 2026.08.01'), findsOneWidget);
    expect(fake.allLeaveRequestQueries, [
      {'status': null, 'startDate': yearStart, 'endDate': yearEnd},
    ]);
    expect(fake.myLeaveRequestQueries, isEmpty);
  });

  testWidgets('조회 - 내역이 없으면 안내 문구와 0건이 표시된다', (tester) async {
    await pumpAllListScreen(tester);

    expect(find.text('조회된 내역이 없습니다.'), findsOneWidget);
    expect(find.text('0건'), findsOneWidget);
  });

  testWidgets('조회 범위 - 내 신청 라디오를 선택하면 my API로 조회한다', (tester) async {
    await pumpAllListScreen(tester);

    // 라벨 텍스트는 탭 영역이 아니므로 라디오 위젯을 직접 탭한다. (두 번째가 내 신청)
    await tester.tap(find.byType(Radio<String>).last);
    await tester.pumpAndSettle();

    expect(fake.myLeaveRequestQueries, [
      {'status': null, 'startDate': yearStart, 'endDate': yearEnd},
    ]);
  });

  testWidgets('상태 필터 - 콤보에서 선택하면 해당 상태로 재조회한다', (tester) async {
    await pumpAllListScreen(tester);

    await tester.tap(find.text('전체').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('승인').last);
    await tester.pumpAndSettle();

    expect(fake.allLeaveRequestQueries.last,
        {'status': 'APPROVED', 'startDate': yearStart, 'endDate': yearEnd});
  });

  testWidgets('신청 취소 - 내 대기 건에만 취소 버튼이 보이고 취소하면 재조회한다', (tester) async {
    fake.allLeaveRequestsToReturn = [
      item(requestId: 11, status: 'PENDING', employeeNumber: 'A0001'),
      item(requestId: 12, status: 'PENDING', employeeNumber: 'B0002'),
    ];
    final me = Employee.fromJson(fixtureJson('admin/employee.json'));

    await pumpAllListScreen(tester, loginUser: me);

    // 내 사번(A0001) 건에만 취소 버튼 노출
    expect(find.text('신청 취소'), findsOneWidget);

    await tester.tap(find.text('신청 취소'));
    await tester.pumpAndSettle();
    expect(find.textContaining('신청을 취소하시겠습니까?'), findsOneWidget);

    await tester.tap(find.text('취소하기'));
    await tester.pumpAndSettle();

    expect(fake.cancelledIds, [11]);
    expect(find.text('신청이 취소되었습니다.'), findsOneWidget);
    expect(fake.allLeaveRequestQueries, hasLength(2)); // 초기 조회 + 취소 후 재조회
  });

  testWidgets('신청 취소 - 로그인 사용자 정보가 없으면 취소 버튼이 없다', (tester) async {
    fake.allLeaveRequestsToReturn = [item(status: 'PENDING')];

    await pumpAllListScreen(tester);

    expect(find.text('신청 취소'), findsNothing);
  });
}
