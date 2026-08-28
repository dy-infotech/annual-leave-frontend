import 'package:annual_leave_frontend/features/leave/widgets/date_range_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// 기간 선택 다이얼로그(DateRangeDialog) 테스트.
///
/// 숫자만 입력받아 yyyy-MM-dd로 자동 정형화하고, 확인 시 범위를 돌려준다.
void main() {
  /// 다이얼로그를 띄우고 닫힐 때 돌려준 값을 담아 둔다.
  Future<List<DateTimeRange?>> openDialog(
    WidgetTester tester, {
    DateTimeRange? initialRange,
  }) async {
    final results = <DateTimeRange?>[];

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<DateTimeRange>(
                context: context,
                builder: (_) => DateRangeDialog(initialRange: initialRange),
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

  Finder startField() => find.widgetWithText(TextField, '시작일');
  Finder endField() => find.widgetWithText(TextField, '종료일');

  String textOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets('초기 범위를 받으면 두 입력란에 채워진다', (tester) async {
    await openDialog(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 21),
      ),
    );

    expect(find.text('기간 선택'), findsOneWidget);
    expect(textOf(tester, startField()), '2026-08-03');
    expect(textOf(tester, endField()), '2026-08-21');
  });

  testWidgets('초기 범위가 없으면 빈 입력란으로 열린다', (tester) async {
    await openDialog(tester);

    expect(textOf(tester, startField()), '');
    expect(textOf(tester, endField()), '');
  });

  testWidgets('숫자만 입력해도 하이픈이 자동으로 붙는다', (tester) async {
    await openDialog(tester);

    await tester.enterText(startField(), '20260810');
    await tester.pump();

    expect(textOf(tester, startField()), '2026-08-10');
  });

  testWidgets('8자리를 넘겨 입력하면 잘린다', (tester) async {
    await openDialog(tester);

    await tester.enterText(startField(), '2026081099');
    await tester.pump();

    expect(textOf(tester, startField()), '2026-08-10');
  });

  testWidgets('숫자가 아닌 문자는 입력되지 않는다', (tester) async {
    await openDialog(tester);

    await tester.enterText(startField(), 'abc2026');
    await tester.pump();

    expect(textOf(tester, startField()), '2026');
  });

  testWidgets('올바른 기간을 확인하면 범위를 돌려주고 닫힌다', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(startField(), '20260810');
    await tester.enterText(endField(), '20260812');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single!.start, DateTime(2026, 8, 10));
    expect(results.single!.end, DateTime(2026, 8, 12));
    expect(find.text('기간 선택'), findsNothing);
  });

  testWidgets('시작일과 종료일이 같아도 확인된다', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(startField(), '20260810');
    await tester.enterText(endField(), '20260810');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(results.single!.start, results.single!.end);
  });

  testWidgets('취소하면 아무 값도 돌려주지 않는다', (tester) async {
    final results = await openDialog(tester);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single, isNull);
  });

  testWidgets('날짜가 비어 있으면 형식 안내를 보여주고 닫지 않는다', (tester) async {
    final results = await openDialog(tester);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('날짜를 yyyy-MM-dd 형식으로 입력해주세요.'), findsOneWidget);
    expect(find.text('기간 선택'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('자릿수가 모자라면 형식 안내를 보여준다', (tester) async {
    await openDialog(tester);

    await tester.enterText(startField(), '2026');
    await tester.enterText(endField(), '20260812');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('날짜를 yyyy-MM-dd 형식으로 입력해주세요.'), findsOneWidget);
  });

  testWidgets('존재하지 않는 날짜는 형식 안내를 보여준다', (tester) async {
    await openDialog(tester);

    // 2026-02-30은 없는 날짜다.
    await tester.enterText(startField(), '20260230');
    await tester.enterText(endField(), '20260301');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('날짜를 yyyy-MM-dd 형식으로 입력해주세요.'), findsOneWidget);
  });

  testWidgets('시작일이 종료일보다 늦으면 안내를 보여주고 닫지 않는다', (tester) async {
    final results = await openDialog(tester);

    await tester.enterText(startField(), '20260815');
    await tester.enterText(endField(), '20260810');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('시작일은 종료일보다 이전이어야 합니다.'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('달력 아이콘을 누르면 날짜 선택기가 열린다', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byIcon(Icons.calendar_today).first);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    // 선택기를 닫아 테스트를 정리한다.
    await tester.tap(find.text('취소').last);
    await tester.pumpAndSettle();
  });
}
