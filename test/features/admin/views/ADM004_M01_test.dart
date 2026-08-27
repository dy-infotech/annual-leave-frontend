import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/admin/views/ADM004_M01.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_admin_employee_repository.dart';
import '../../../helpers/test_doubles/fake_common_code_repository.dart';

/// 사원 사번 조회 화면(ADM004_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다.
void main() {
  late FakeAdminEmployeeRepository fake;
  late FakeCommonCodeRepository fakeCodes;

  setUp(() {
    fake = FakeAdminEmployeeRepository();
    fakeCodes = FakeCommonCodeRepository();
  });

  Employee employee({
    String employeeNumber = 'A0001',
    String name = '홍길동',
    String team = 'SI사업팀',
    bool isRegisted = true,
  }) {
    final json = fixtureJson('admin/employee.json')
      ..['employeeNumber'] = employeeNumber
      ..['name'] = name
      ..['team'] = team
      ..['isRegisted'] = isRegisted;
    return Employee.fromJson(json);
  }

  Future<void> pumpSearchScreen(WidgetTester tester) async {
    await pumpApp(
      tester,
      SearchEmployeeNumberScreen(
        repository: fake,
        commonCodeRepository: fakeCodes,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('조회 - 사원 카드에 이름, 사번, 이메일, 등록 상태가 표시된다', (tester) async {
    fake.employeesToReturn = [
      employee(isRegisted: true),
      employee(employeeNumber: 'B0002', name: '김미등', isRegisted: false),
    ];

    await pumpSearchScreen(tester);

    expect(find.text('사용자 정보 조회'), findsOneWidget);
    expect(find.text('2건'), findsOneWidget);
    expect(find.text('홍길동 과장 (A0001)'), findsOneWidget);
    expect(find.text('김미등 과장 (B0002)'), findsOneWidget);
    expect(find.text('등록'), findsWidgets);
    expect(find.text('미등록'), findsWidgets);
    expect(fake.fetchQueries, ['']); // 검색어 없이 조회
  });

  testWidgets('조회 - 내역이 없으면 안내 문구가 표시된다', (tester) async {
    await pumpSearchScreen(tester);

    expect(find.text('조회된 내역이 없습니다.'), findsOneWidget);
  });

  testWidgets('등록 상태 필터 - 미등록을 선택하면 미등록 사원만 남는다', (tester) async {
    fake.employeesToReturn = [
      employee(isRegisted: true),
      employee(employeeNumber: 'B0002', name: '김미등', isRegisted: false),
    ];

    await pumpSearchScreen(tester);

    await tester.tap(find.text('전체').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('미등록').last);
    await tester.pumpAndSettle();

    expect(find.text('1건'), findsOneWidget);
    expect(find.text('김미등 과장 (B0002)'), findsOneWidget);
    expect(find.text('홍길동 과장 (A0001)'), findsNothing);
  });

  testWidgets('팀 필터 - 조회 결과에서 추출한 팀 목록으로 필터링한다', (tester) async {
    fake.employeesToReturn = [
      employee(team: 'SI사업팀'),
      employee(employeeNumber: 'B0002', name: '박비아', team: 'BI사업팀'),
    ];

    await pumpSearchScreen(tester);

    // 팀 드롭다운(두 번째 '전체')을 열고 BI사업팀 선택
    await tester.tap(find.text('전체').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BI사업팀').last);
    await tester.pumpAndSettle();

    expect(find.text('1건'), findsOneWidget);
    expect(find.text('박비아 과장 (B0002)'), findsOneWidget);
    expect(find.text('홍길동 과장 (A0001)'), findsNothing);
  });

  testWidgets('검색 - 사번/성명 입력 후 검색하면 검색어가 전달된다', (tester) async {
    await pumpSearchScreen(tester);

    await tester.enterText(find.byType(TextField), '홍길동');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(fake.fetchQueries.last, '홍길동');
  });
}
