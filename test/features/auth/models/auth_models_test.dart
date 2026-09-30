import 'package:annual_leave_frontend/features/auth/models/auth_models.dart';
import 'package:annual_leave_frontend/features/auth/models/enums/RoleType.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('LoginRequest', () {
    test('toJson은 사번과 비밀번호를 담는다', () {
      final json = LoginRequest(employeeNumber: 'A0001', password: 'pw').toJson();
      expect(json, {'employeeNumber': 'A0001', 'password': 'pw'});
    });
  });

  group('LoginResponse', () {
    test('fromJson은 응답 필드를 그대로 매핑한다', () {
      final res = LoginResponse.fromJson(fixtureJson('auth/login_response.json'));
      expect(res.token, 'header.payload.signature');
      expect(res.employeeId, 7);
      expect(res.name, '홍길동');
      expect(res.role, 'ADMIN');
    });

    test('isAdmin은 role이 ADMIN일 때만 true', () {
      final admin = LoginResponse.fromJson(fixtureJson('auth/login_response.json'));
      expect(admin.isAdmin, isTrue);

      final member = LoginResponse(
          token: 't', employeeId: 1, name: 'n', role: 'EMPLOYEE');
      expect(member.isAdmin, isFalse);
    });
  });

  group('SignUpRequest', () {
    test('toJson은 사번과 비밀번호를 담는다', () {
      final json = SignUpRequest(employeeNumber: 'A0002', password: 'pw2').toJson();
      expect(json, {'employeeNumber': 'A0002', 'password': 'pw2'});
    });
  });

  group('SyncFcmTokenRequest', () {
    test('toJson은 토큰과 기기 OS를 담는다', () {
      final json = SyncFcmTokenRequest(fcmToken: 'fcm', deviceOs: 'web').toJson();
      expect(json, {'fcmToken': 'fcm', 'deviceOs': 'web'});
    });
  });

  group('AdminAuthRegisterRequest', () {
    test('toJson은 등록 정보 8개 필드를 모두 담는다', () {
      final json = AdminAuthRegisterRequest(
        employeeNumber: 'A0003',
        name: '이등록',
        department: '경영지원부',
        team: 'SI사업팀',
        position: '대리',
        role: 'EMPLOYEE',
        email: 'lee@example.com',
        hireDate: '2026-01-01',
      ).toJson();
      expect(json, {
        'employeeNumber': 'A0003',
        'name': '이등록',
        'department': '경영지원부',
        'team': 'SI사업팀',
        'position': '대리',
        'role': 'EMPLOYEE',
        'email': 'lee@example.com',
        'hireDate': '2026-01-01',
      });
    });
  });

  group('RoleType', () {
    test('코드와 라벨 매핑이 유지된다', () {
      expect(RoleType.admin.code, 'ADMIN');
      expect(RoleType.admin.label, '관리자');
      expect(RoleType.employee.code, 'EMPLOYEE');
      expect(RoleType.employee.label, '멤버');
    });
  });
}
