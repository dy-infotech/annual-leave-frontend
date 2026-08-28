import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/employee/view_models/EMP001_M01_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_auth_session.dart';
import '../../../helpers/test_doubles/fake_employee_repository.dart';

void main() {
  late FakeEmployeeRepository repository;
  late FakeAuthSession session;

  Employee me({String email = 'hong@example.com'}) =>
      Employee.fromJson(fixtureJson('admin/employee.json')..['email'] = email);

  setUp(() {
    repository = FakeEmployeeRepository();
    session = FakeAuthSession(employeeInfo: me());
  });

  MyInfoViewModel build() =>
      MyInfoViewModel(authProvider: session, repository: repository);

  group('MyInfoViewModel - 비밀번호 변경', () {
    test('세 항목 중 하나라도 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();

      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '모든 항목을 입력해주세요.');

      vm.currentPasswordController.text = 'old1234';
      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '모든 항목을 입력해주세요.');

      vm.newPasswordController.text = 'new1234';
      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '모든 항목을 입력해주세요.');

      expect(repository.passwordChanges, isEmpty);
    });

    test('새 비밀번호와 확인이 다르면 불일치 메시지를 남긴다', () async {
      final vm = build();
      vm.currentPasswordController.text = 'old1234';
      vm.newPasswordController.text = 'new1234';
      vm.newPasswordConfirmController.text = 'new9999';

      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '새 비밀번호가 일치하지 않습니다.');
      expect(repository.passwordChanges, isEmpty);
    });

    test('새 비밀번호가 현재 비밀번호와 같으면 거부한다', () async {
      final vm = build();
      vm.currentPasswordController.text = 'old1234';
      vm.newPasswordController.text = 'old1234';
      vm.newPasswordConfirmController.text = 'old1234';

      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '현재 비밀번호와 다른 비밀번호를 입력해주세요.');
      expect(repository.passwordChanges, isEmpty);
    });

    test('성공 - 변경 요청 후 입력란을 모두 비운다', () async {
      final vm = build();
      vm.currentPasswordController.text = 'old1234';
      vm.newPasswordController.text = 'new1234';
      vm.newPasswordConfirmController.text = 'new1234';

      expect(await vm.changePassword(), isTrue);
      expect(repository.passwordChanges, [
        {'currentPassword': 'old1234', 'newPassword': 'new1234'}
      ]);
      expect(vm.currentPasswordController.text, isEmpty);
      expect(vm.newPasswordController.text, isEmpty);
      expect(vm.newPasswordConfirmController.text, isEmpty);
      expect(vm.errorMessage, isNull);
      expect(vm.isSubmitting, isFalse);
    });

    test('실패 - 고정 문구를 남기고 입력값은 유지한다', () async {
      repository.changePasswordErrorToThrow = Exception('401');

      final vm = build();
      vm.currentPasswordController.text = 'old1234';
      vm.newPasswordController.text = 'new1234';
      vm.newPasswordConfirmController.text = 'new1234';

      expect(await vm.changePassword(), isFalse);
      expect(vm.errorMessage, '현재 비밀번호가 일치하지 않거나 변경에 실패했습니다.');
      expect(vm.currentPasswordController.text, 'old1234');
      expect(vm.isSubmitting, isFalse);
    });
  });

  group('MyInfoViewModel - 이메일 편집', () {
    test('startEditingEmail - 세션의 기존 이메일을 입력란에 채운다', () {
      final vm = build();

      vm.startEditingEmail();

      expect(vm.isEditingEmail, isTrue);
      expect(vm.emailController.text, 'hong@example.com');
    });

    test('startEditingEmail - 세션 정보가 없으면 빈 문자열로 시작한다', () {
      session = FakeAuthSession();
      final vm = build();

      vm.startEditingEmail();

      expect(vm.isEditingEmail, isTrue);
      expect(vm.emailController.text, isEmpty);
    });

    test('이메일이 비어 있으면 API를 호출하지 않는다', () async {
      final vm = build();

      expect(await vm.changeEmail(), isFalse);
      expect(vm.emailErrorMessage, '이메일 정보를 입력해 주세요.');
      expect(repository.emailChanges, isEmpty);
    });

    test('이메일 형식이 아니면 형식 오류 메시지를 남긴다', () async {
      final vm = build();

      for (final invalid in [
        'hong',
        'hong@',
        'hong@example',
        '@example.com',
        'hong example@test.com',
        'hong@example.c',
      ]) {
        vm.emailController.text = invalid;
        expect(await vm.changeEmail(), isFalse, reason: invalid);
        expect(vm.emailErrorMessage, '올바른 이메일 형식이 아닙니다.', reason: invalid);
      }
      expect(repository.emailChanges, isEmpty);
    });

    test('올바른 형식이면 통과한다', () async {
      final vm = build();

      for (final valid in [
        'hong@example.com',
        'hong.gil-dong@sub.example.co.kr',
        'a_b@ex-ample.io',
      ]) {
        vm.emailController.text = valid;
        expect(await vm.changeEmail(), isTrue, reason: valid);
      }
      expect(repository.emailChanges, [
        'hong@example.com',
        'hong.gil-dong@sub.example.co.kr',
        'a_b@ex-ample.io'
      ]);
    });

    test('성공 - 세션 이메일을 갱신하고 편집 모드를 끝낸다', () async {
      final vm = build();
      vm.startEditingEmail();
      vm.emailController.text = 'new@example.com';

      expect(await vm.changeEmail(), isTrue);
      expect(repository.emailChanges, ['new@example.com']);
      expect(session.updatedEmails, ['new@example.com']);
      expect(vm.isEditingEmail, isFalse);
      expect(vm.emailController.text, isEmpty);
      expect(vm.emailErrorMessage, isNull);
      expect(vm.isSubmitting, isFalse);
    });

    test('실패 - 편집 모드를 유지하고 세션을 갱신하지 않는다', () async {
      repository.changeEmailErrorToThrow = Exception('409');

      final vm = build();
      vm.startEditingEmail();
      vm.emailController.text = 'new@example.com';

      expect(await vm.changeEmail(), isFalse);
      expect(vm.emailErrorMessage, '이메일 변경에 실패했습니다.');
      expect(session.updatedEmails, isEmpty);
      expect(vm.isEditingEmail, isTrue);
      expect(vm.emailController.text, 'new@example.com');
      expect(vm.isSubmitting, isFalse);
    });
  });
}
