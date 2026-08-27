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
