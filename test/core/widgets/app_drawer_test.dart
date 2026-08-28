import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/fixture_reader.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles/fake_auth_session.dart';

/// 전역 드로어(AppDrawer)의 권한별 메뉴 노출 테스트.
///
/// 일반 사원 / 관리자 / 대표(사장·대표이사) 세 단계로 메뉴가 갈린다.
void main() {
  Employee employee({
    String position = '과장',
    String role = 'EMPLOYEE',
    String name = '홍길동',
    String team = 'SI사업팀',
  }) =>
      Employee.fromJson(fixtureJson('admin/employee.json')
        ..['position'] = position
        ..['role'] = role
        ..['name'] = name
        ..['team'] = team);

  /// 드로어를 연 상태의 화면을 띄운다.
  Future<void> pumpDrawer(WidgetTester tester, {Employee? info}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      const Scaffold(drawer: AppDrawer(), body: SizedBox.shrink()),
      providers: [
        ChangeNotifierProvider<AuthSession>(
            create: (_) => FakeAuthSession(employeeInfo: info)),
      ],
    );

    // 드로어 열기
    final state = tester.state<ScaffoldState>(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();
  }

  /// 로그인한 누구에게나 보이는 기본 메뉴.
  const baseMenus = ['대시보드', '휴가 신청', '신청 목록', '내 정보'];
  const adminMenus = ['결재 대기 목록', '사용자 등록 관리', '사용자 정보 조회'];
  const ceoMenus = ['부서 및 팀 관리', '관리자별 관리팀 설정'];

  group('프로필 영역', () {
    testWidgets('이름과 직급, 소속팀과 사번을 표시한다', (tester) async {
      await pumpDrawer(tester,
          info: employee(name: '우동영', position: '대표이사', team: '대표이사'));

      expect(find.text('우동영 대표이사'), findsOneWidget);
      expect(find.textContaining('대표이사 · A0001'), findsOneWidget);
    });

    testWidgets('사원 정보가 없으면 빈 프로필로 그려지고 기본 메뉴는 남는다', (tester) async {
      await pumpDrawer(tester, info: null);

      for (final label in baseMenus) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in [...adminMenus, ...ceoMenus]) {
        expect(find.text(label), findsNothing);
      }
    });
  });

  group('권한별 메뉴 노출', () {
    testWidgets('일반 사원 - 기본 메뉴만 보이고 관리자 영역은 숨는다', (tester) async {
      await pumpDrawer(tester, info: employee(role: 'EMPLOYEE'));

      for (final label in baseMenus) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('관리자 전용 Menu'), findsNothing);
      for (final label in [...adminMenus, ...ceoMenus]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('로그아웃'), findsOneWidget);
    });

    testWidgets('관리자(대표 아님) - 관리자 메뉴는 보이고 대표 전용은 숨는다', (tester) async {
      await pumpDrawer(tester, info: employee(role: 'ADMIN', position: '이사'));

      expect(find.text('관리자 전용 Menu'), findsOneWidget);
      for (final label in adminMenus) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in ceoMenus) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('사장 - 대표 전용 메뉴까지 모두 보인다', (tester) async {
      await pumpDrawer(tester, info: employee(role: 'ADMIN', position: '사장'));

      for (final label in [...baseMenus, ...adminMenus, ...ceoMenus]) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('대표이사 표기도 사장과 동일하게 대표 전용 메뉴가 보인다', (tester) async {
      await pumpDrawer(tester, info: employee(role: 'ADMIN', position: '대표이사'));

      for (final label in ceoMenus) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('대표 직급이어도 역할이 ADMIN이 아니면 관리자 영역이 숨는다', (tester) async {
      await pumpDrawer(tester, info: employee(role: 'EMPLOYEE', position: '사장'));

      expect(find.text('관리자 전용 Menu'), findsNothing);
      for (final label in [...adminMenus, ...ceoMenus]) {
        expect(find.text(label), findsNothing);
      }
    });
  });

  group('메뉴 이동', () {
    testWidgets('휴가 신청을 누르면 해당 경로로 이동한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        const Scaffold(drawer: AppDrawer(), body: SizedBox.shrink()),
        providers: [
          ChangeNotifierProvider<AuthSession>(
              create: (_) => FakeAuthSession(employeeInfo: employee())),
        ],
        routes: {
          '/leave-request': (_) =>
              const Scaffold(body: Text('leave-request-stub')),
        },
      );

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('휴가 신청'));
      await tester.pumpAndSettle();

      expect(find.text('leave-request-stub'), findsOneWidget);
    });
  });
}
