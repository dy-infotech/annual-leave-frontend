import 'package:annual_leave_frontend/features/admin/models/department_team_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fixture_reader.dart';

void main() {
  group('Department', () {
    test('fromJson은 부서 정보를 매핑한다', () {
      final dept = Department.fromJson(fixtureJson('admin/department.json'));

      expect(dept.departmentId, 2);
      expect(dept.departmentName, '경영지원부');
      expect(dept.enabled, isTrue);
    });

    test('대표이사 부서만 보호 대상이다', () {
      expect(
        Department(departmentId: 1, departmentName: kCeoName).isProtected,
        isTrue,
      );
      expect(
        Department.fromJson(fixtureJson('admin/department.json')).isProtected,
        isFalse,
      );
    });
  });

  group('TeamManager', () {
    test('display는 이름과 직급을 붙여 표시한다', () {
      final manager = TeamManager(
          employeeId: 5, employeeNumber: 'A0001', name: '홍길동', position: '부장');
      expect(manager.display, '홍길동 부장');
    });

    test('직급이 없으면 이름만 표시한다', () {
      final manager = TeamManager(
          employeeId: 5, employeeNumber: 'A0001', name: '홍길동', position: '');
      expect(manager.display, '홍길동');
    });
  });

  group('Team', () {
    test('fromJson은 소속 부서/상위 팀/담당자 목록을 매핑한다', () {
      final team = Team.fromJson(fixtureJson('admin/team.json'));

      expect(team.teamId, 3);
      expect(team.teamName, 'SI사업팀');
      expect(team.departmentId, 2);
      expect(team.parentTeamId, 1);
      expect(team.parentTeamName, '대표이사');
      expect(team.managers, hasLength(1));
      expect(team.managers.first.name, '홍길동');
    });

    test('상위 팀이 자기 자신이면 루트 팀이다', () {
      final root = Team(teamId: 1, teamName: '대표이사', parentTeamId: 1);
      expect(root.isRoot, isTrue);

      final normal = Team.fromJson(fixtureJson('admin/team.json'));
      expect(normal.isRoot, isFalse);
    });
  });

  group('TeamCreateRequest', () {
    test('toJson은 상위 팀 미지정 시 parentTeamId를 body에서 제외한다', () {
      final json = TeamCreateRequest(
        teamName: '신규팀',
        projectManagerId: 5,
        departmentId: 2,
      ).toJson();

      expect(json, {
        'teamName': '신규팀',
        'projectManagerId': 5,
        'departmentId': 2,
      });
      expect(json.containsKey('parentTeamId'), isFalse);
    });

    test('toJson은 상위 팀 지정 시 parentTeamId를 포함한다', () {
      final json = TeamCreateRequest(
        teamName: '신규팀',
        projectManagerId: 5,
        departmentId: 2,
        parentTeamId: 1,
      ).toJson();

      expect(json['parentTeamId'], 1);
    });
  });

  group('TeamUpdateRequest', () {
    test('null 필드는 body에서 제외된다', () {
      final json = TeamUpdateRequest(teamName: '개명팀').toJson();
      expect(json, {'teamName': '개명팀'});
    });

    test('모든 필드가 null이면 isEmpty가 true다', () {
      expect(TeamUpdateRequest().isEmpty, isTrue);
      expect(TeamUpdateRequest(projectManagerId: 5).isEmpty, isFalse);
    });
  });
}
