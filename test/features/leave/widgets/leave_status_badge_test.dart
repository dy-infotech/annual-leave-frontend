import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/features/leave/widgets/leave_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// 휴가 상태 뱃지의 라벨/색상 매핑 테스트.
void main() {
  Future<void> pumpBadge(WidgetTester tester, String status) async {
    await pumpApp(
      tester,
      Scaffold(body: Center(child: LeaveStatusBadge(status: status))),
    );
  }

  Color textColorOf(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).style!.color!;

  testWidgets('PENDING은 대기로 표시된다', (tester) async {
    await pumpBadge(tester, 'PENDING');

    expect(find.text('대기'), findsOneWidget);
    expect(textColorOf(tester), AppColors.amber);
  });

  testWidgets('APPROVED는 승인으로 표시된다', (tester) async {
    await pumpBadge(tester, 'APPROVED');

    expect(find.text('승인'), findsOneWidget);
    expect(textColorOf(tester), AppColors.sage);
  });

  testWidgets('REJECTED는 반려로 표시된다', (tester) async {
    await pumpBadge(tester, 'REJECTED');

    expect(find.text('반려'), findsOneWidget);
    expect(textColorOf(tester), AppColors.coral);
  });

  testWidgets('CANCELLED는 취소로 표시된다', (tester) async {
    await pumpBadge(tester, 'CANCELLED');

    expect(find.text('취소'), findsOneWidget);
    expect(textColorOf(tester), AppColors.textMuted);
  });

  testWidgets('모르는 상태는 받은 문자열을 그대로 보여준다', (tester) async {
    await pumpBadge(tester, 'UNKNOWN_STATE');

    expect(find.text('UNKNOWN_STATE'), findsOneWidget);
    expect(textColorOf(tester), AppColors.textMuted);
  });

  testWidgets('빈 문자열도 예외 없이 그려진다', (tester) async {
    await pumpBadge(tester, '');

    expect(find.byType(LeaveStatusBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
