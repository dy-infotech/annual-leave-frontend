import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/widgets/employee_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';

/// 사원 선택 다이얼로그(EmployeePickerDialog) 테스트.
///
/// 검색 함수를 주입할 수 있어 API 없이 검증한다.
void main() {
  Employee employee({
    required String number,
    required String name,
    String position = '사원',
    String team = 'SI사업팀',
  }) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['employeeNumber'] = number
        ..['name'] = name
        ..['position'] = position
        ..['team'] = team);

  late List<String?> searchKeywords;

  setUp(() {
    searchKeywords = [];
  });

  /// 다이얼로그를 띄우고 선택 결과를 담아 둔다.
  Future<List<Employee?>> openDialog(
    WidgetTester tester, {
    required Future<List<Employee>> Function(String? keyword) searchFn,
    List<String> exclude = const [],
    String title = '사원 선택',
  }) async {
    final results = <Employee?>[];

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final picked = await showDialog<Employee>(
                context: context,
                builder: (_) => EmployeePickerDialog(
                  searchFn: searchFn,
                  excludeEmployeeNumbers: exclude,
                  title: title,
                ),
              );
              results.add(picked);
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

  Future<List<Employee>> Function(String?) searchReturning(
          List<Employee> items) =>
      (keyword) async {
        searchKeywords.add(keyword);
        return items;
      };

  testWidgets('열면 곧바로 전체 목록을 조회해 보여준다', (tester) async {
    await openDialog(
      tester,
      searchFn: searchReturning([
        employee(number: 'A0001', name: '홍길동', position: '과장'),
        employee(number: 'A0002', name: '김철수', team: 'BI사업팀'),
      ]),
    );

    expect(find.text('사원 선택'), findsOneWidget);
    expect(find.text('홍길동 과장'), findsOneWidget);
    expect(find.textContaining('A0001 · SI사업팀'), findsOneWidget);
    expect(find.text('김철수 사원'), findsOneWidget);
    expect(searchKeywords, ['']);
  });

  testWidgets('제목을 넘기면 그대로 표시된다', (tester) async {
    await openDialog(
      tester,
      title: '팀 담당자 선택',
      searchFn: searchReturning([]),
    );

    expect(find.text('팀 담당자 선택'), findsOneWidget);
  });

  testWidgets('결과가 없으면 안내 문구를 보여준다', (tester) async {
    await openDialog(tester, searchFn: searchReturning([]));

    expect(find.text('조회된 사원이 없습니다.'), findsOneWidget);
  });

  testWidgets('이미 선택된 사번은 목록에서 제외된다', (tester) async {
    await openDialog(
      tester,
      exclude: ['A0001'],
      searchFn: searchReturning([
        employee(number: 'A0001', name: '홍길동'),
        employee(number: 'A0002', name: '김철수'),
      ]),
    );

    expect(find.text('홍길동 사원'), findsNothing);
    expect(find.text('김철수 사원'), findsOneWidget);
  });

  testWidgets('검색어를 넣고 검색하면 그 검색어로 다시 조회한다', (tester) async {
    await openDialog(
      tester,
      searchFn: searchReturning([employee(number: 'A0002', name: '김철수')]),
    );

    await tester.enterText(find.byType(TextField), '김철');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(searchKeywords, ['', '김철']);
  });

  testWidgets('돋보기 아이콘을 눌러도 다시 조회한다', (tester) async {
    await openDialog(tester, searchFn: searchReturning([]));

    await tester.enterText(find.byType(TextField), 'A000');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(searchKeywords, ['', 'A000']);
  });

  testWidgets('사원을 누르면 그 사원을 돌려주고 닫힌다', (tester) async {
    final results = await openDialog(
      tester,
      searchFn: searchReturning([
        employee(number: 'A0001', name: '홍길동', position: '과장'),
      ]),
    );

    await tester.tap(find.text('홍길동 과장'));
    await tester.pumpAndSettle();

    expect(results.single!.employeeNumber, 'A0001');
    expect(find.text('사원 선택'), findsNothing);
  });

  testWidgets('닫기를 누르면 아무 값도 돌려주지 않는다', (tester) async {
    final results = await openDialog(
      tester,
      searchFn: searchReturning([employee(number: 'A0001', name: '홍길동')]),
    );

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(results.single, isNull);
  });

  testWidgets('조회에 실패하면 오류 문구와 다시 시도 버튼을 보여준다', (tester) async {
    var callCount = 0;
    await openDialog(
      tester,
      searchFn: (keyword) async {
        callCount++;
        throw Exception('network');
      },
    );

    expect(find.text('사원 목록을 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(callCount, 1);
  });

  testWidgets('다시 시도를 누르면 재조회한다', (tester) async {
    var callCount = 0;
    await openDialog(
      tester,
      searchFn: (keyword) async {
        callCount++;
        if (callCount == 1) throw Exception('network');
        return [employee(number: 'A0001', name: '홍길동', position: '과장')];
      },
    );

    expect(find.text('사원 목록을 불러오지 못했습니다.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('홍길동 과장'), findsOneWidget);
    expect(find.text('사원 목록을 불러오지 못했습니다.'), findsNothing);
  });

  testWidgets('직급이 비어 있으면 이름만, 팀이 비어 있으면 팀 미지정으로 보여준다', (tester) async {
    await openDialog(
      tester,
      searchFn: searchReturning([
        employee(number: 'A0003', name: '박신입', position: '', team: ''),
      ]),
    );

    expect(find.text('박신입'), findsOneWidget);
    expect(find.textContaining('A0003 · 팀 미지정'), findsOneWidget);
  });
}
