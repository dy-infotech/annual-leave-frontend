import 'package:annual_leave_frontend/features/admin/models/employee.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';
import '../../../helpers/test_doubles/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository fake;

  setUp(() {
    fake = FakeAuthRepository();
    fake.myInfoToReturn =
        Employee.fromJson(fixtureJson('admin/employee.json'));
  });

  group('AuthSession', () {
    test('login 성공 - 로그인 상태, 역할, 내 정보가 세팅된다', () async {
      final session = AuthSession(repository: fake);

      await session.login('A0001', 'pw');

      expect(fake.signInCalls, [
        {'employeeNumber': 'A0001', 'password': 'pw'},
      ]);
      expect(session.isLoggedIn, isTrue);
      expect(session.name, '홍길동');
      expect(session.isAdmin, isFalse);
      expect(session.employeeInfo?.employeeNumber, 'A0001');
    });

    test('login - signin과 /me role이 다르면 /me의 현재 role을 사용한다', () async {
      fake.myInfoToReturn = fake.myInfoToReturn!.copyWith(
        role: 'ADMIN',
        name: '현재 관리자',
      );
      final session = AuthSession(repository: fake);

      await session.login('A0001', 'pw');

      expect(fake.signInResponse.role, 'EMPLOYEE');
      expect(session.isAdmin, isTrue);
      expect(session.name, '현재 관리자');
      expect(session.employeeInfo?.role, 'ADMIN');
    });

    test('login 후 내 정보 조회가 실패하면 토큰과 세션을 롤백한다', () async {
      fake.myInfoToReturn = null;
      final session = AuthSession(repository: fake);

      await expectLater(session.login('A0001', 'pw'), throwsA(isA<Exception>()));

      expect(fake.storedToken, isNull);
      expect(session.isLoggedIn, isFalse);
      expect(session.name, isNull);
      expect(session.employeeInfo, isNull);
    });

    test('tryAutoLogin - 저장된 토큰이 없으면 로그인 상태가 아니다', () async {
      final session = AuthSession(repository: fake);

      await session.tryAutoLogin();

      expect(session.isLoggedIn, isFalse);
    });

    test('tryAutoLogin - 토큰이 있으면 내 정보를 조회해 로그인 상태가 된다', () async {
      fake.storedToken = 'stored.token';
      final session = AuthSession(repository: fake);

      await session.tryAutoLogin();

      expect(session.isLoggedIn, isTrue);
      expect(session.employeeInfo, isNotNull);
    });

    test('tryAutoLogin - 자동 로그인 해제 시 기존 로컬 토큰을 지우고 복원하지 않는다', () async {
      fake.storedToken = 'stored.token';
      final session = AuthSession(repository: fake);

      await session.tryAutoLogin(enabled: false);

      expect(session.isLoggedIn, isFalse);
      expect(fake.storedToken, isNull);
      expect(session.employeeInfo, isNull);
    });

    test('tryAutoLogin - 내 정보 조회 실패 시 토큰을 지우고 비로그인 상태로 돌린다', () async {
      fake.storedToken = 'stored.token';
      fake.myInfoToReturn = null; // 조회 실패 유도
      final session = AuthSession(repository: fake);

      await session.tryAutoLogin();

      expect(session.isLoggedIn, isFalse);
      expect(fake.storedToken, isNull);
    });

    test('logout - 세션 상태가 초기화되고 토큰이 삭제된다', () async {
      fake.storedToken = 'stored.token';
      final session = AuthSession(repository: fake);
      await session.login('A0001', 'pw');

      await session.logout();

      expect(session.isLoggedIn, isFalse);
      expect(session.name, isNull);
      expect(session.employeeInfo, isNull);
      expect(fake.storedToken, isNull);
    });

    test('updateEmail - 보관 중인 내 정보의 이메일이 갱신된다', () async {
      final session = AuthSession(repository: fake);
      await session.login('A0001', 'pw');

      await session.updateEmail('new@example.com');

      expect(session.employeeInfo?.email, 'new@example.com');
    });
  });
}
