import 'package:annual_leave_frontend/features/auth/view_models/AUT003_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_doubles/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;

  setUp(() {
    fake = FakeAuthRepository();
  });

  FindAccountViewModel build() => FindAccountViewModel(repository: fake);

  group('FindAccountViewModel - 아이디 찾기', () {
    test('성함이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.emailForIdController.text = 'hong@example.com';

      expect(await vm.findId(), isFalse);
      expect(vm.errorMessage, '성함과 이메일을 모두 입력해 주세요.');
      expect(fake.findIdCalls, isEmpty);
    });

    test('이메일이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.nameController.text = '홍길동';

      expect(await vm.findId(), isFalse);
      expect(vm.errorMessage, '성함과 이메일을 모두 입력해 주세요.');
      expect(fake.findIdCalls, isEmpty);
    });

    test('성공 - 성함과 이메일의 공백을 제거해 전달한다', () async {
      final vm = build();
      vm.nameController.text = '  홍길동  ';
      vm.emailForIdController.text = '  hong@example.com  ';

      expect(await vm.findId(), isTrue);
      expect(fake.findIdCalls, [
        {'name': '홍길동', 'email': 'hong@example.com'}
      ]);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('실패 - 예외 종류와 무관하게 고정 문구를 남긴다', () async {
      fake.findIdErrorToThrow = Exception('404 not found');

      final vm = build();
      vm.nameController.text = '홍길동';
      vm.emailForIdController.text = 'hong@example.com';

      expect(await vm.findId(), isFalse);
      expect(vm.errorMessage, '등록된 정보가 일치하지 않습니다.');
      expect(vm.isLoading, isFalse);
    });
  });

  group('FindAccountViewModel - 비밀번호 재설정 메일', () {
    test('사번이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.emailForPwController.text = 'hong@example.com';

      expect(await vm.sendPasswordResetEmail(), isFalse);
      expect(vm.errorMessage, '사번과 이메일을 모두 입력해 주세요.');
      expect(fake.resetCalls, isEmpty);
    });

    test('이메일이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();
      vm.employeeNoController.text = 'A0001';

      expect(await vm.sendPasswordResetEmail(), isFalse);
      expect(vm.errorMessage, '사번과 이메일을 모두 입력해 주세요.');
      expect(fake.resetCalls, isEmpty);
    });

    test('성공 - 사번과 이메일의 공백을 제거해 전달한다', () async {
      final vm = build();
      vm.employeeNoController.text = '  A0001  ';
      vm.emailForPwController.text = '  hong@example.com  ';

      expect(await vm.sendPasswordResetEmail(), isTrue);
      expect(fake.resetCalls, [
        {'employeeNumber': 'A0001', 'email': 'hong@example.com'}
      ]);
      expect(vm.errorMessage, isNull);
      expect(vm.isLoading, isFalse);
    });

    test('실패 - 발송 실패 문구를 남긴다', () async {
      fake.resetErrorToThrow = Exception('mail server down');

      final vm = build();
      vm.employeeNoController.text = 'A0001';
      vm.emailForPwController.text = 'hong@example.com';

      expect(await vm.sendPasswordResetEmail(), isFalse);
      expect(vm.errorMessage, '등록된 정보가 일치하지 않거나 발송에 실패했습니다.');
      expect(vm.isLoading, isFalse);
    });
  });

  group('FindAccountViewModel - 탭 전환', () {
    test('clearInputs는 에러 메시지만 지운다. (입력값은 그대로 남는다)', () async {
      final vm = build();
      vm.nameController.text = '홍길동';
      await vm.findId(); // 이메일이 비어 있어 에러 메시지가 남는다
      expect(vm.errorMessage, isNotNull);

      var notified = 0;
      vm.addListener(() => notified++);

      vm.clearInputs();

      expect(vm.errorMessage, isNull);
      expect(notified, 1);
      // 이름과 달리 컨트롤러 입력값은 유지된다. (현재 동작 기록)
      expect(vm.nameController.text, '홍길동');
    });
  });
}
