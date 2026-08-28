import 'package:annual_leave_frontend/features/admin/widgets/date_input_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// 단일 날짜 입력 다이얼로그(DateInputDialog) 테스트.
///
/// 입사일/퇴사일 지정에 쓰이며 숫자만 입력받아 yyyy-MM-dd로 정형화한다.
void main() {
  Future<List<DateTime?>> openDialog(
    WidgetTester tester, {
    DateTime? initialDate,
    String title = '날짜 선택',
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final results = <DateTime?>[];

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<DateTime>(
                context: context,
                builder: (_) => DateInputDialog(
                  initialDate: initialDate,
                  title: title,
                  firstDate: firstDate,
                  lastDate: lastDate,
                ),
              );
              results.add(result);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return results;
  }

  String inputText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('기본 제목은 날짜 선택이다', (tester) async {
    await openDialog(tester);

    expect(find.text('날짜 선택'), findsOneWidget);
  });

  testWidgets('제목을 넘기면 그대로 표시된다', (tester) async {
    await openDialog(tester, title: '입사일 선택');

    expect(find.text('입사일 선택'), findsOneWidget);
  });

  testWidgets('초기 날짜를 받으면 입력란에 채워진다', (tester) async {
    await openDialog(tester, initialDate: DateTime(2025, 3, 7));

    expect(inputText(tester), '2025-03-07');
  });

  testWidgets('초기 날짜가 없으면 빈 입력란으로 열린다', (tester) async {
    await openDialog(tester);

    expect(inputText(tester), '');
  });

  testWidgets('숫자만 입력해도 하이픈이 자동으로 붙는다', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '20260215');
    await tester.pump();

    expect(inputText(tester), '2026-02-15');
  });

  testWidgets('올바른 날짜를 확인하면 그 날짜를 돌려준다', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(find.byType(TextField), '20260215');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(results.single, DateTime(2026, 2, 15));
    expect(find.text('날짜 선택'), findsNothing);
  });

  testWidgets('취소하면 아무 값도 돌려주지 않는다', (tester) async {
    final results = await openDialog(tester, initialDate: DateTime(2026, 2, 15));

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
  });

  testWidgets('비어 있으면 형식 안내를 보여주고 닫지 않는다', (tester) async {
    final results = await openDialog(tester);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('날짜를 yyyy-MM-dd 형식으로 입력하세요.'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('존재하지 않는 날짜는 형식 안내를 보여준다', (tester) async {
    final results = await openDialog(tester);

    // 2025-02-29는 없는 날짜다(2025년은 평년).
    await tester.enterText(find.byType(TextField), '20250229');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('날짜를 yyyy-MM-dd 형식으로 입력하세요.'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('윤년 2월 29일은 정상 처리된다', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(find.byType(TextField), '20240229');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(results.single, DateTime(2024, 2, 29));
  });

  testWidgets('달력 아이콘을 누르면 날짜 선택기가 열린다', (tester) async {
    await openDialog(tester, initialDate: DateTime(2026, 2, 15));

    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
  });
}
