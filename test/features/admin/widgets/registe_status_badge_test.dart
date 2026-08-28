import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/features/admin/widgets/registe_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// 사용자 등록 상태 뱃지의 라벨/색상 매핑 테스트.
void main() {
  Future<void> pumpBadge(WidgetTester tester, String status) async {
    await pumpApp(
      tester,
      Scaffold(body: Center(child: RegisteStatusBadge(status: status))),
    );
  }

  Color textColorOf(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).style!.color!;

  testWidgets('등록 상태는 sage 색으로 표시된다', (tester) async {
    await pumpBadge(tester, '등록');

    expect(find.text('등록'), findsOneWidget);
    expect(textColorOf(tester), AppColors.sage);
  });

  testWidgets('미등록 상태는 흐린 색으로 표시된다', (tester) async {
    await pumpBadge(tester, '미등록');

    expect(find.text('미등록'), findsOneWidget);
    expect(textColorOf(tester), AppColors.textMuted);
  });

  testWidgets('모르는 상태는 받은 문자열을 그대로 보여준다', (tester) async {
    await pumpBadge(tester, '보류');

    expect(find.text('보류'), findsOneWidget);
    expect(textColorOf(tester), AppColors.textMuted);
  });
}
