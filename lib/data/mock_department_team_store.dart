import 'package:flutter/foundation.dart';

import '../models/department_team_models.dart';
import '../models/employee.dart';

/// 부서/팀 데이터를 임시 목업으로 대체할지 여부.
///
/// 백엔드에 부서/팀 CRUD API 가 준비되면 **이 값을 false 로 바꾸기만 하면** 실제 API 를 쓴다.
/// (필요한 엔드포인트 목록은 docs/api-spec-department-team.md 참고)
const bool kUseMockDepartmentTeamData = true;

// 임시 목업 저장소.
//
// 백엔드에 부서/팀 CRUD API가 없어(docs/api-spec-department-team.md 참고)
// 화면 동작을 확인할 수 없으므로, API 호출이 실패하면 이 저장소로 대체한다.
// 메모리에만 존재하므로 앱을 다시 시작하면 초기 상태로 돌아간다.
//
// TODO: 백엔드 API가 준비되면 이 파일과 화면의 목업 분기를 함께 삭제할 것.
class MockDepartmentTeamStore {
  MockDepartmentTeamStore._();

  static final MockDepartmentTeamStore instance = MockDepartmentTeamStore._();

  final List<Department> _departments = [];
  final List<Team> _teams = [];
  final List<Employee> _employees = [];

  int _deptSeq = 0;
  int _teamSeq = 0;
  bool _seeded = false;

  /// 테스트에서 시드 상태로 되돌린다.
  @visibleForTesting
  void reset() {
    _departments.clear();
    _teams.clear();
    _employees.clear();
    _deptSeq = 0;
    _teamSeq = 0;
    _seeded = false;
  }

  /// 백엔드 sql/data.sql 의 초기 데이터를 그대로 옮겨 심는다.
  void _ensureSeeded() {
    if (_seeded) return;
    _seeded = true;

    for (final name in const ['대표이사', 'SI사업팀']) {
      _departments.add(Department(departmentId: ++_deptSeq, departmentName: name));
    }

    _employees.addAll([
      _emp('A2011001', '우동영', '사장', 'SI사업팀', '대표이사'),
      _emp('A2020001', '이호영', '이사', 'SI사업팀', '스마트팩토리구축사업'),
      _emp('A2025015', '이서우', '사원', 'SI사업팀', '스마트팩토리구축사업'),
      _emp('A2025016', '최민지', '사원', 'SI사업팀', '스마트팩토리구축사업'),
      _emp('A2022004', '김도현', '과장', 'SI사업팀', '스마트팩토리구축사업'),
      _emp('A2023007', '박지연', '대리', 'SI사업팀', '스마트팩토리구축사업'),
    ]);

    // 루트 팀은 자기 자신을 상위 팀으로 갖는다(백엔드 시드와 동일).
    _teams.add(Team(
      teamId: ++_teamSeq,
      teamName: '대표이사',
      parentTeam: '대표이사',
      managers: [_managerOf('A2011001')],
    ));
    _teams.add(Team(
      teamId: ++_teamSeq,
      teamName: '스마트팩토리구축사업',
      parentTeam: '대표이사',
      managers: [_managerOf('A2020001')],
    ));
  }

  static Employee _emp(
    String number,
    String name,
    String position,
    String department,
    String team,
  ) {
    return Employee(
      employeeNumber: number,
      name: name,
      position: position,
      department: department,
      team: team,
      teamList: null,
      currTotalLeaveDays: 15,
      remainingLeaveDays: 15,
      isRegisted: true,
    );
  }

  TeamManager _managerOf(String employeeNumber) {
    final e = _employees.firstWhere((e) => e.employeeNumber == employeeNumber);
    return TeamManager(
      employeeNumber: e.employeeNumber,
      name: e.name,
      position: e.position,
    );
  }

  // ------------------------------------------------------------ 조회

  List<Department> fetchDepartments() {
    _ensureSeeded();
    // 부서별 팀 수는 관계 정보가 없어 채우지 않는다(실제 백엔드에도 연결 필드가 없음).
    return List<Department>.unmodifiable(_departments);
  }

  List<Team> fetchTeams() {
    _ensureSeeded();
    return List<Team>.unmodifiable(_teams);
  }

  /// 사원 검색. 검색어는 사번 또는 성명 부분 일치.
  List<Employee> searchEmployees(String? keyword) {
    _ensureSeeded();
    final q = keyword?.trim() ?? '';
    if (q.isEmpty) return List<Employee>.unmodifiable(_employees);
    return _employees
        .where((e) =>
            e.employeeNumber.toLowerCase().contains(q.toLowerCase()) ||
            e.name.contains(q))
        .toList();
  }

  // ------------------------------------------------------------ 저장

  /// 부서 등록/수정. departmentId 가 null 이면 신규 등록.
  /// 이름이 중복되면 예외를 던진다(서버 제약을 흉내).
  void saveDepartment({int? departmentId, required String departmentName}) {
    _ensureSeeded();
    final duplicated = _departments.any((d) =>
        d.departmentName == departmentName && d.departmentId != departmentId);
    if (duplicated) {
      throw StateError('이미 존재하는 부서명입니다.');
    }

    if (departmentId == null) {
      _departments
          .add(Department(departmentId: ++_deptSeq, departmentName: departmentName));
      return;
    }

    final index =
        _departments.indexWhere((d) => d.departmentId == departmentId);
    if (index < 0) throw StateError('존재하지 않는 부서입니다.');
    _departments[index] =
        Department(departmentId: departmentId, departmentName: departmentName);
  }

  /// 팀 등록/수정. teamId 가 null 이면 신규 등록.
  void saveTeam({
    int? teamId,
    required String teamName,
    required String parentTeam,
    required List<TeamManager> managers,
  }) {
    _ensureSeeded();
    if (managers.isEmpty) {
      // 백엔드 project_manager_id NOT NULL 과 동일한 제약
      throw StateError('팀 관리자를 최소 1명 지정해야 합니다.');
    }
    final duplicated =
        _teams.any((t) => t.teamName == teamName && t.teamId != teamId);
    if (duplicated) {
      throw StateError('이미 존재하는 팀명입니다.');
    }

    final saved = Team(
      teamId: teamId ?? ++_teamSeq,
      teamName: teamName,
      parentTeam: parentTeam,
      managers: List<TeamManager>.unmodifiable(managers),
    );

    if (teamId == null) {
      _teams.add(saved);
      return;
    }

    final index = _teams.indexWhere((t) => t.teamId == teamId);
    if (index < 0) throw StateError('존재하지 않는 팀입니다.');

    // 팀 이름이 바뀌면 이 팀을 상위 팀으로 참조하던 팀들도 함께 갱신한다.
    final previousName = _teams[index].teamName;
    _teams[index] = saved;
    if (previousName != teamName) {
      for (var i = 0; i < _teams.length; i++) {
        if (i != index && _teams[i].parentTeam == previousName) {
          _teams[i] = Team(
            teamId: _teams[i].teamId,
            teamName: _teams[i].teamName,
            parentTeam: teamName,
            managers: _teams[i].managers,
          );
        }
      }
    }
  }
}
