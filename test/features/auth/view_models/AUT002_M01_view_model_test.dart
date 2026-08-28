import 'package:annual_leave_frontend/features/auth/view_models/AUT002_M01_view_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_doubles/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;

  setUp(() {
    fake = FakeAuthRepository();
  });

  SignupViewModel build() => SignupViewModel(repository: fake);

  group('SignupViewModel - 입력 검증', () {
    test('사번이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw1234';

      expect(await vm.signUp(), isFalse);
      expect(vm.errorMessage, '사번과 비밀번호를 입력해 주세요.');
      expect(fake.signUpCalls, isEmpty);
    });

    test('비밀번호가 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.employeeNumberController.text = 'A0001';

      expect(await vm.signUp(), isFalse);
      expect(vm.errorMessage, '사번과 비밀번호를 입력해 주세요.');
      expect(fake.signUpCalls, isEmpty);
    });

    test('비밀번호 확인이 다르면 불일치 메시지를 남긴다', () async {
      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw9999';

      expect(await vm.signUp(), isFalse);
      expect(vm.errorMessage, '비밀번호가 일치하지 않습니다.');
      expect(fake.signUpCalls, isEmpty);
    });
  });

  group('SignupViewModel - 등록 요청', () {
    test('성공 - 사번의 공백을 제거해 전달하고 true를 돌려준다', () async {
      final vm = build();
      vm.employeeNumberController.text = '  A0001  ';
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw1234';

      expect(await vm.signUp(), isTrue);
      expect(fake.signUpCalls, [
        {'employeeNumber': 'A0001', 'password': 'pw1234'}
      ]);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('실패 - DioException이면 예외 문자열을 그대로 노출한다', () async {
      fake.signUpErrorToThrow = DioException(
        requestOptions: RequestOptions(path: '/api/auth/signup'),
        message: '이미 등록된 사번입니다.',
      );

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw1234';

      expect(await vm.signUp(), isFalse);
      expect(vm.errorMessage, contains('DioException'));
      expect(vm.errorMessage, contains('이미 등록된 사번입니다.'));
      expect(vm.isLoading, isFalse);
    });

    test('실패 - DioException이 아니면 고정 문구로 대체한다', () async {
      fake.signUpErrorToThrow = Exception('서버 내부 오류');

      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw1234';

      expect(await vm.signUp(), isFalse);
      expect(vm.errorMessage, '사용 등록에 실패했습니다.');
    });

    test('로딩 상태는 요청 전후로 켜졌다 꺼진다', () async {
      final vm = build();
      vm.employeeNumberController.text = 'A0001';
      vm.passwordController.text = 'pw1234';
      vm.passwordConfirmController.text = 'pw1234';

      final loadingStates = <bool>[];
      vm.addListener(() => loadingStates.add(vm.isLoading));

      await vm.signUp();

      expect(loadingStates, [true, false]);
    });
  });
}
