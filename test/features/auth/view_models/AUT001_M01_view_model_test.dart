import 'dart:async';

import 'package:annual_leave_frontend/features/auth/view_models/AUT001_M01_view_model.dart';
import 'package:annual_leave_frontend/features/leave/models/public_holiday.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_doubles/fake_auth_session.dart';
import '../../../helpers/test_doubles/fake_public_holiday_repository.dart';

/// 공휴일 프리페치 호출 횟수를 세기 위한 로컬 페이크.
class _CountingHolidayRepository extends FakePublicHolidayRepository {
  int fetchCount = 0;

  @override
  Future<List<PublicHoliday>> fetchPublicHolidays({bool refresh = false}) {
    fetchCount++;
    return super.fetchPublicHolidays(refresh: refresh);
  }
}

class _GatedHolidayRepository extends _CountingHolidayRepository {
  final Completer<void> entered = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<List<PublicHoliday>> fetchPublicHolidays({bool refresh = false}) async {
    fetchCount++;
    if (!entered.isCompleted) entered.complete();
    await release.future;
    if (errorToThrow != null) throw errorToThrow!;
    return holidaysToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  late Map<String, String> secureStore;
  late List<String> secureMethods;
  late bool failSecureStorageDelete;
  late FakeAuthSession session;
  late _CountingHolidayRepository holidayRepository;

  LoginViewModel build() => LoginViewModel(
        authSession: session,
        holidayRepository: holidayRepository,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStore = {};
    secureMethods = [];
    failSecureStorageDelete = false;

    // 비밀번호 저장소는 플랫폼 채널을 타므로 인메모리 맵으로 대신한다.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      secureMethods.add(call.method);
      final args = Map<String, dynamic>.from(call.arguments as Map);
      switch (call.method) {
        case 'read':
          return secureStore[args['key'] as String];
        case 'write':
          secureStore[args['key'] as String] = args['value'] as String;
          return null;
        case 'delete':
          if (failSecureStorageDelete) {
            throw PlatformException(code: 'delete-failed');
          }
          secureStore.remove(args['key'] as String);
          return null;
        case 'containsKey':
          return secureStore.containsKey(args['key'] as String);
        case 'readAll':
          return Map<String, String>.from(secureStore);
        case 'deleteAll':
          secureStore.clear();
          return null;
      }
      return null;
    });

    session = FakeAuthSession();
    holidayRepository = _CountingHolidayRepository();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  group('LoginViewModel - 계정 저장 정보 불러오기', () {
    test('loadSavedAccountInfo - 저장 여부가 없으면 입력값을 채우지 않는다', () async {
      final vm = build();

      await vm.loadSavedAccountInfo();

      expect(vm.isRememberMe, isFalse);
      expect(vm.isAutoLoginEnabled, isTrue);
      expect(vm.employeeNumberController.text, isEmpty);
      expect(vm.passwordController.text, isEmpty);
      // 저장을 안 한 상태에서는 암호 저장소를 읽지 않는다.
      expect(secureMethods, isEmpty);
    });

    test('loadSavedAccountInfo - 저장된 사번만 불러오고 레거시 비밀번호는 삭제한다', () async {
      SharedPreferences.setMockInitialValues({
        'isRememberMe': true,
        'savedEmployeeNumber': 'A0001',
      });
      secureStore['savedPassword'] = 'pw1234';

      final vm = build();
      await vm.loadSavedAccountInfo();

      expect(vm.isRememberMe, isTrue);
      expect(vm.employeeNumberController.text, 'A0001');
      expect(vm.passwordController.text, isEmpty);
      expect(secureStore.containsKey('savedPassword'), isFalse);
      expect(secureMethods, contains('delete'));
    });

    test('loadSavedAccountInfo - 저장 여부는 true인데 값이 없으면 빈 문자열로 채운다', () async {
      SharedPreferences.setMockInitialValues({'isRememberMe': true});

      final vm = build();
      await vm.loadSavedAccountInfo();

      expect(vm.isRememberMe, isTrue);
      expect(vm.employeeNumberController.text, isEmpty);
      expect(vm.passwordController.text, isEmpty);
    });

    test('setRememberMe / toggleRememberMe - 값을 바꾸고 리스너에 알린다', () {
      final vm = build();
      var notified = 0;
      vm.addListener(() => notified++);

      vm.setRememberMe(true);
      expect(vm.isRememberMe, isTrue);

      vm.toggleRememberMe();
      expect(vm.isRememberMe, isFalse);

      vm.toggleRememberMe();
      expect(vm.isRememberMe, isTrue);
      expect(notified, 3);
    });

    test('자동 로그인 설정을 저장값에서 불러오고 독립적으로 토글한다', () async {
      SharedPreferences.setMockInitialValues({'autoLoginEnabled': false});

      final vm = build();
      await vm.loadSavedAccountInfo();

      expect(vm.isRememberMe, isFalse);
      expect(vm.isAutoLoginEnabled, isFalse);

      vm.setAutoLoginEnabled(true);
      expect(vm.isAutoLoginEnabled, isTrue);

      vm.toggleAutoLogin();
      expect(vm.isAutoLoginEnabled, isFalse);
    });
  });

  group('LoginViewModel - 로그인', () {
    test('입력이 비어 있으면 API를 호출하지 않고 안내 메시지를 남긴다', () async {
      final vm = build();

      expect(await vm.login(), isFalse);
      expect(vm.errorMessage, '사번과 비밀번호를 입력해주세요.');
      expect(session.loginCalls, isEmpty);

      vm.employeeNumberController.text = 'A0001';
      expect(await vm.login(), isFalse);
      expect(vm.errorMessage, '사번과 비밀번호를 입력해주세요.');
      expect(session.loginCalls, isEmpty);
    });

    test('성공 - 사번은 공백을 제거해 전달하고 공휴일을 미리 조회한다', () async {
      final vm = build();
      vm.employeeNumberController.text = '  A0001  ';
      vm.passwordController.text = 'pw1234';

      final ok = await vm.login();

      expect(ok, isTrue);
      expect(session.loginCalls, [
        {'employeeNumber': 'A0001', 'password': 'pw1234'}
      ]);
      expect(holidayRepository.fetchCount, 1);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('성공 + 사번 저장 체크 - 사번만 저장하고 비밀번호는 남기지 않는다', () async {
      final vm = build();
      vm.employeeNumberController.text = '  A0001  ';
      vm.passwordController.text = 'pw1234';
      vm.setRememberMe(true);

      expect(await vm.login(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isRememberMe'), isTrue);
      expect(prefs.getString('savedEmployeeNumber'), 'A0001');
      expect(secureStore.containsKey('savedPassword'), isFalse);
      expect(secureMethods, contains('delete'));
    });

    test('성공 + 자동 로그인 해제 - 사번 저장과 무관하게 설정을 별도로 저장한다', () async {
      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.setRememberMe(false);
      vm.setAutoLoginEnabled(false);

      expect(await vm.login(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isRememberMe'), isNull);
      expect(prefs.getString('savedEmployeeNumber'), isNull);
      expect(prefs.getBool('autoLoginEnabled'), isFalse);
    });

    test('성공 + 계정 저장 해제 - 저장돼 있던 사번과 비밀번호를 모두 지운다', () async {
      SharedPreferences.setMockInitialValues({
        'isRememberMe': true,
        'savedEmployeeNumber': 'A0001',
      });
      secureStore['savedPassword'] = 'pw1234';

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.setRememberMe(false);

      expect(await vm.login(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isRememberMe'), isNull);
      expect(prefs.getString('savedEmployeeNumber'), isNull);
      expect(secureStore, isEmpty);
      expect(secureMethods, contains('delete'));
    });

    test('레거시 비밀번호 삭제가 실패해도 이미 성공한 로그인은 유지한다', () async {
      failSecureStorageDelete = true;

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.setRememberMe(true);

      expect(await vm.login(), isTrue);
      expect(session.loginCalls, [
        {'employeeNumber': 'A0001', 'password': 'pw1234'}
      ]);
      expect(vm.errorMessage, isNull);
      expect(holidayRepository.fetchCount, 1);
    });

    test('로그인 후 부가 작업 중 세션 generation이 바뀌면 성공 화면 전환을 막는다', () async {
      final gatedHolidayRepository = _GatedHolidayRepository();
      holidayRepository = gatedHolidayRepository;

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';

      final pending = vm.login();
      await gatedHolidayRepository.entered.future;

      // 다른 탭 로그인/세션 만료가 현재 로그인 이후 발생한 상황을 모델링한다.
      session.advanceGeneration();
      gatedHolidayRepository.release.complete();

      expect(await pending, isFalse);
      expect(gatedHolidayRepository.fetchCount, 1);
      expect(vm.isLoading, isFalse);
    });

    test('공휴일 프리페치가 실패해도 로그인 성공으로 처리한다', () async {
      holidayRepository.errorToThrow = Exception('공휴일 조회 실패');

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';

      expect(await vm.login(), isTrue);
      expect(vm.errorMessage, isNull);
      expect(holidayRepository.fetchCount, 1);
    });

    test('실패 - 예외 문자열을 그대로 메시지로 노출하고 계정 정보를 저장하지 않는다', () async {
      session.loginErrorToThrow = Exception('사번 또는 비밀번호가 올바르지 않습니다.');

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'wrong';
      vm.setRememberMe(true);

      expect(await vm.login(), isFalse);
      expect(vm.errorMessage, contains('사번 또는 비밀번호가 올바르지 않습니다.'));
      expect(vm.isLoading, isFalse);
      // 저장과 공휴일 조회는 로그인 성공 이후에만 수행된다.
      expect(secureStore, isEmpty);
      expect(holidayRepository.fetchCount, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isRememberMe'), isNull);
    });
  });
}
