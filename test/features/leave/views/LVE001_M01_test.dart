import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE001_M01.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles/fake_auth_session.dart';
import '../../../helpers/test_doubles/fake_leave_repository.dart';
import '../../../helpers/test_doubles/fake_public_holiday_repository.dart';

/// 휴가 신청 화면(LVE001_M01) 특성화 테스트.
///
/// 화면이 provider와 dio를 통해 실제로 주고받는 요청/응답을 HTTP 계층에서
/// 모킹해 현재 동작을 기록한다. 신청 성공 시나리오는 요청 본문까지
/// 정확히 일치해야 통과한다. 이후 리팩터링 단계에서 이 테스트는
/// 수정 없이 통과해야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  late FakeLeaveRepository leaveRepository;
  late FakePublicHolidayRepository holidayRepository;
  late Employee employeeInfo;

  final now = DateTime.now();

  DateTime selectableDayInCurrentMonth() {
    for (var day = 8; day <= 14; day++) {
      final candidate = DateTime(now.year, now.month, day);
      if (candidate.weekday != DateTime.saturday &&
          candidate.weekday != DateTime.sunday) {
        return candidate;
      }
    }
    throw StateError('현재 월에서 테스트용 평일을 찾을 수 없습니다.');
  }

  final selectableDay = selectableDayInCurrentMonth();

  String selectedDate() =>
      '${selectableDay.year}-${selectableDay.month.toString().padLeft(2, '0')}-${selectableDay.day.toString().padLeft(2, '0')}';

  setUp(() {
    leaveRepository = FakeLeaveRepository();
    holidayRepository = FakePublicHolidayRepository();
  });

  void stubCommon({
    List<Map<String, dynamic>> myList = const [],
    double remainingLeaveDays = 11.5,
  }) {
    final employee = fixtureJson('admin/employee.json')
      ..['remainingLeaveDays'] = remainingLeaveDays;
    employeeInfo = Employee.fromJson(employee);
    leaveRepository.leavePeriodToReturn = LeavePeriod(
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year, 12, 31),
    );
    leaveRepository.myLeaveRequestsToReturn = myList
        .map((json) => LeaveRequestListItem.fromJson(json))
        .toList();
    holidayRepository.holidaysToReturn = [];
  }

  Future<void> pumpLeaveRequestScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      LeaveRequestScreen(
        repository: leaveRepository,
        holidayRepository: holidayRepository,
      ),
      providers: [
        ChangeNotifierProvider<AuthSession>(
          create: (_) => FakeAuthSession(employeeInfo: employeeInfo),
        ),
      ],
    );
    await pumpFor(tester, duration: const Duration(seconds: 1));
  }

  Future<void> selectLeaveType(WidgetTester tester, String label) async {
    await tester.tap(find.text('연차').first);
    await pumpFor(tester, duration: const Duration(milliseconds: 500));
    await tester.tap(find.text(label).last);
    await pumpFor(tester, duration: const Duration(milliseconds: 500));
  }

  testWidgets('진입 - 신청자, 결재자, 잔여 연차가 표시된다', (tester) async {
    stubCommon();

    await pumpLeaveRequestScreen(tester);

    expect(find.text('휴가 신청'), findsOneWidget);
    expect(find.text('홍길동 과장'), findsOneWidget);
    expect(find.text('김결재 부장'), findsOneWidget);
    expect(find.text('잔여 11.5일'), findsOneWidget);
    expect(find.text('0 일'), findsOneWidget);
  });

  testWidgets('신청 - 날짜를 선택하지 않으면 안내 메시지가 표시된다', (tester) async {
    stubCommon();

    await pumpLeaveRequestScreen(tester);

    await tester.tap(find.text('신청하기'));
    await pumpFor(tester, duration: const Duration(milliseconds: 300));

    expect(find.text('날짜를 선택해주세요.'), findsOneWidget);
  });

  testWidgets('반차 신청 성공 - 확인 다이얼로그를 거쳐 제출되고 폼이 초기화된다', (tester) async {
    stubCommon();
    await pumpLeaveRequestScreen(tester);

    await selectLeaveType(tester, '반차(오전)');
    await tester.tap(find.text('${selectableDay.day}'));
    await pumpFor(tester, duration: const Duration(milliseconds: 500));
    expect(find.text('0.5 일'), findsOneWidget);

    await tester.tap(find.text('신청하기'));
    await pumpFor(tester, duration: const Duration(milliseconds: 500));
    expect(find.text('휴가 신청 확인'), findsOneWidget);
    expect(find.text('반차(오전)'), findsWidgets);
    expect(find.text('0.5일'), findsOneWidget);

    await tester.tap(find.text('신청'));
    await pumpFor(tester, duration: const Duration(seconds: 1));

    expect(find.text('휴가 신청이 완료되었습니다.'), findsOneWidget);
    // 폼 초기화: 사용 연차 0, 종류 연차로 복귀
    expect(find.text('0 일'), findsOneWidget);
    expect(find.text('연차'), findsOneWidget);
  });

  testWidgets('중복 신청 - 같은 시간대 반차가 있으면 차단 안내가 표시된다', (tester) async {
    final existing = fixtureJson('leave/leave_request_list_item.json')
      ..['leaveType'] = 'AM_HALF'
      ..['status'] = 'PENDING'
      ..['startDate'] = selectedDate()
      ..['endDate'] = selectedDate()
      ..['useDays'] = 0.5;
    stubCommon(myList: [existing]);

    await pumpLeaveRequestScreen(tester);

    await selectLeaveType(tester, '반차(오전)');
    await tester.tap(find.text('${selectableDay.day}'));
    await pumpFor(tester, duration: const Duration(milliseconds: 500));

    expect(find.text('중복 신청 안내'), findsOneWidget);
  });

  testWidgets('중복 신청 - 같은 날 다른 시간대 반차는 허용된다', (tester) async {
    final existing = fixtureJson('leave/leave_request_list_item.json')
      ..['leaveType'] = 'AM_HALF'
      ..['status'] = 'PENDING'
      ..['startDate'] = selectedDate()
      ..['endDate'] = selectedDate()
      ..['useDays'] = 0.5;
    stubCommon(myList: [existing]);

    await pumpLeaveRequestScreen(tester);

    await selectLeaveType(tester, '반차(오후)');
    await tester.tap(find.text('${selectableDay.day}'));
    await pumpFor(tester, duration: const Duration(milliseconds: 500));

    expect(find.text('중복 신청 안내'), findsNothing);
    expect(find.text('잔여 연차 부족 안내'), findsNothing);
  });

  testWidgets('잔여 연차 초과 - 부족 안내가 표시된다', (tester) async {
    stubCommon(remainingLeaveDays: 0.0);

    await pumpLeaveRequestScreen(tester);

    await selectLeaveType(tester, '반차(오전)');
    await tester.tap(find.text('${selectableDay.day}'));
    await pumpFor(tester, duration: const Duration(milliseconds: 500));

    expect(find.text('잔여 연차 부족 안내'), findsOneWidget);
  });

  testWidgets('사유 입력란 - 연차/반차 외 종류를 선택하면 표시된다', (tester) async {
    stubCommon();

    await pumpLeaveRequestScreen(tester);

    expect(find.text('사유'), findsNothing);
    await selectLeaveType(tester, '가족 돌봄');

    expect(find.text('사유'), findsOneWidget);
    expect(find.text('휴가 사유를 입력해주세요'), findsOneWidget);
  });
}
