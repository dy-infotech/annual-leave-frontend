import 'package:annual_leave_frontend/data/mock_department_team_store.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/screens/department_team_manage_screen.dart';
import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 부서 및 팀 관리 화면의 요구사항 6가지를 검증한다.
///   부서: 조회 / 수정 / 추가
///   팀  : 조회 / 수정 / 추가 (관리자 최소 1명, 사용자 조회로 할당)
///
/// 백엔드에 부서/팀 CRUD API 가 없으므로 화면은 목업 저장소로 대체 동작한다.
/// 이 테스트는 그 목업 경로가 실제로 6가지를 모두 수행하는지 확인한다.
void main() {
  setUp(() => MockDepartmentTeamStore.instance.reset());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
        child: MaterialApp(
          theme: AppTheme.theme,
          home: const DepartmentTeamManageScreen(),
        ),
      ),
    );
    // API 호출 실패 → 목업으로 대체될 때까지 기다린다.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('대표이사').evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('부서 조회 — 목록이 표시된다', (tester) async {
    await pumpScreen(tester);

    expect(find.text('부서 및 팀 관리'), findsOneWidget);
    expect(find.text('부서'), findsWidgets);
    expect(find.text('팀'), findsWidgets);

    // 목업 시드 부서 2건
    expect(find.text('대표이사'), findsWidgets);
    expect(find.text('SI사업팀'), findsOneWidget);
    expect(find.text('2건'), findsWidgets);
  });

  testWidgets('부서 추가 — 다이얼로그로 등록하면 목록에 반영된다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('부서 추가'));
    await settle(tester);
    expect(find.text('부서 추가'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '신규사업부');
    await tester.tap(find.text('등록'));
    await settle(tester);

    expect(find.text('신규사업부'), findsOneWidget);
  });

  testWidgets('부서 수정 — 항목을 눌러 이름을 바꾸면 반영된다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('SI사업팀'));
    await settle(tester);
    expect(find.text('부서 수정'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'SI사업본부');
    await tester.tap(find.text('수정'));
    await settle(tester);

    expect(find.text('SI사업본부'), findsOneWidget);
    expect(find.text('SI사업팀'), findsNothing);
  });

  testWidgets('팀 조회 — 팀과 관리자가 표시된다', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('팀').last);
    await settle(tester);

    expect(find.text('스마트팩토리구축사업'), findsOneWidget);
    // 관리자 이름·직급이 카드에 노출된다
    expect(find.textContaining('이호영 이사'), findsWidgets);
    expect(find.textContaining('관리자 1명'), findsWidgets);
  });

  testWidgets('팀 추가 — 관리자를 지정하지 않으면 저장되지 않는다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('팀').last);
    await settle(tester);

    await tester.tap(find.text('팀 추가'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '신규팀');
    // 상위 팀 선택
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('대표이사').last);
    await settle(tester);

    await tester.tap(find.text('등록'));
    await settle(tester);

    // 관리자 미지정이므로 다이얼로그가 닫히지 않고 오류가 표시된다
    expect(find.text('팀 관리자를 최소 1명 지정해 주세요.'), findsOneWidget);
  });

  testWidgets('팀 추가 — 사용자를 조회해 관리자를 할당하면 등록된다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('팀').last);
    await settle(tester);

    await tester.tap(find.text('팀 추가'));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '품질관리팀');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('대표이사').last);
    await settle(tester);

    // 사용자 조회 다이얼로그를 열어 한 명 선택
    await tester.tap(find.text('+ 추가'));
    await settle(tester);
    expect(find.text('팀 관리자 선택'), findsOneWidget);

    await tester.tap(find.textContaining('김도현').first);
    await settle(tester);

    // 선택한 관리자가 칩으로 표시된다
    expect(find.text('김도현 과장'), findsOneWidget);

    await tester.tap(find.text('등록'));
    await settle(tester);

    expect(find.text('품질관리팀'), findsOneWidget);
  });

  testWidgets('팀 수정 — 기존 팀의 상위 팀이 유실되지 않는다', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('팀').last);
    await settle(tester);

    await tester.tap(find.text('스마트팩토리구축사업'));
    await settle(tester);
    expect(find.text('팀 수정'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '스마트팩토리사업부');
    await tester.tap(find.text('수정'));
    await settle(tester);

    expect(find.text('스마트팩토리사업부'), findsOneWidget);
    // 상위 팀이 null 로 날아가지 않고 유지된다
    expect(find.textContaining('상위 팀 · 대표이사'), findsWidgets);
  });
}
