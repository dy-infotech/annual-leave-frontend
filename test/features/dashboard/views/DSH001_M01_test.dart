import 'package:annual_leave_frontend/features/dashboard/models/dashboard_models.dart';
import 'package:annual_leave_frontend/features/dashboard/views/DSH001_M01.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE003_M01.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_dashboard_data_source.dart';

/// 대시보드 화면(DSH001_M01) 특성화 테스트.
///
/// ViewModel 추출 전의 현재 동작을 기록한다. 이후 리팩터링 단계에서
/// 이 테스트는 수정 없이 통과해야 한다. (주입 배선만 변경 가능)
void main() {
  DashboardData adminData() =>
      DashboardData.fromJson(fixtureJson('dashboard/dashboard.json'));

  DashboardData memberData() => DashboardData.fromJson(
      fixtureJson('dashboard/dashboard.json')
        ..['allEmployeeRequestSummary'] = null);

  testWidgets('일반 사용자 - 내 휴가 정보와 신청 현황이 표시되고 관리자 섹션은 없다', (tester) async {
    await pumpDashboardScreen(tester, data: memberData());

    expect(find.text('대시보드'), findsOneWidget);
    expect(find.text('내 휴가 정보'), findsOneWidget);
    expect(find.text('15'), findsOneWidget); // 배정
    expect(find.text('3.5'), findsOneWidget); // 사용
    expect(find.text('11.5'), findsOneWidget); // 잔여
    expect(find.text('내 휴가 신청 현황'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // 대기
    expect(find.text('4'), findsOneWidget); // 승인
    expect(find.text('전직원 휴가 신청 현황'), findsNothing);
  });

  testWidgets('관리자 - 전직원 신청 현황 섹션과 관리자 뱃지가 표시된다', (tester) async {
    await pumpDashboardScreen(tester, data: adminData());

    expect(find.text('전직원 휴가 신청 현황'), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 전직원 대기
    expect(find.text('10'), findsOneWidget); // 전직원 승인
  });

  testWidgets('조회 실패 - 오류 메시지와 다시 시도 버튼이 표시된다', (tester) async {
    await pumpDashboardScreen(tester,
        errorMessage: '대시보드 정보를 불러오지 못했습니다.');

    expect(find.text('대시보드 정보를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('관리자 대기 클릭 - 결재 대기 목록 화면으로 이동한다', (tester) async {
    await pumpDashboardScreen(tester, data: adminData());

    await tester.tap(find.text('2'));
    await pumpFor(tester, duration: const Duration(seconds: 1));

    expect(find.byType(PendingApprovalScreen), findsOneWidget);
  });
}
