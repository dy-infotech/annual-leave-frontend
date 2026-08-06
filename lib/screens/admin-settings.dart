import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/employee.dart'; // 기존 Employee 모델 경로 확인
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  List<Employee> _employees = [];
  Employee? _selectedEmployee;

  List<String> _generalTeams = []; // 중앙: 일반 팀 목록
  List<String> _managedTeams = []; // 우측: 관리자 팀 목록
  Set<String> _changedTeams = {}; // 변경된 팀 목록 추적

  String? _selectedGeneralTeam; // 선택된 일반 팀
  String? _selectedManagedTeam; // 선택된 관리자 팀
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  // 1️⃣ 사원 전체 목록 로드 (왼쪽 컬럼용)
  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/api/admin/employees/all');
      final List<Employee> fetched = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .toList();
      setState(() {
        _employees = fetched;
        if (_employees.isNotEmpty) {
          _selectedEmployee = _employees.first; // 기본 첫 사원 자동 선택
          _fetchEmployeeTeams();
        }
      });
    } catch (e) {
      print('사원 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2️⃣ 선택된 사원의 '일반 팀' 및 '관리자 팀' 분리 로드 (중앙/우측 컬럼용)
  Future<void> _fetchEmployeeTeams() async {
    if (_selectedEmployee == null) return;
    try {
      // 공통 기초 데이터에서 시스템 전체의 모든 팀 목록 확보
      final commonResponse =
          await ApiClient().dio.get('/api/admin/auth/common');

      List<String> rawAllTeams = [];
      if (commonResponse.data != null &&
          commonResponse.data is Map<String, dynamic>) {
        final commonData = commonResponse.data as Map<String, dynamic>;
        final rawTeams =
            commonData['accessibleTeam'] ?? commonData['team'] ?? [];
        if (rawTeams is List) {
          rawAllTeams = rawTeams.map((e) => e.toString()).toList();
        }
      }

      // 🎯 [핵심] DB 중복 이름 방어: 동일한 이름이 있으면 "대표이사 (1)", "대표이사 (2)" 형태로 유니크하게 변환
      final List<String> uniqueAllTeams = [];
      final Map<String, int> nameCounter = {};

      for (var originalName in rawAllTeams) {
        if (nameCounter.containsKey(originalName)) {
          nameCounter[originalName] = nameCounter[originalName]! + 1;
          uniqueAllTeams.add('$originalName (${nameCounter[originalName]})');
        } else {
          nameCounter[originalName] = 1;
          // 첫 번째는 깔끔하게 원본 이름 유지 (또는 일괄적으로 '팀명 (1)' 형식을 맞춰도 됨)
          uniqueAllTeams.add(originalName);
        }
      }

      // 🎯 1. 사용자의 권한 역할(Role) 파싱
      final String currentRole = (_selectedEmployee!.role ?? '').toUpperCase();
      final bool isAdmin = currentRole == 'ADMIN' || currentRole == 'MANAGER';

      final List<String> currentManaged = [];

      // 🎯 2. 관리자('ADMIN')인 경우 사원의 teamList 매핑 구성
      if (isAdmin) {
        // 사원 정보에 들어있는 원본 팀명 목록들
        final List<String> empTeams = [];
        if (_selectedEmployee!.teamList != null) {
          empTeams.addAll(_selectedEmployee!.teamList!);
        }

        // 사원이 가진 원본 이름을 위에서 만든 고유 변환 이름 목록(uniqueAllTeams)과 매핑하여 순서대로 할당
        // 이를 통해 DB에 중복 저장된 이름 개수만큼 순서대로 관리팀에 채워 넣습니다.
        for (var empTeamName in empTeams) {
          // uniqueAllTeams 중에서 해당 원본 이름으로 시작하는 유니크 이름을 찾아서 추가
          final matchedUniqueTeams = uniqueAllTeams
              .where((uTeam) =>
                  uTeam == empTeamName || uTeam.startsWith('$empTeamName ('))
              .toList();

          for (var matched in matchedUniqueTeams) {
            if (!currentManaged.contains(matched)) {
              currentManaged.add(matched);
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        // 🎯 3. 최종 할당 및 중복 없는 필터링
        _managedTeams = isAdmin ? List<String>.from(currentManaged) : [];

        // 고유 문자열 구조이므로 이제 명확하게 걸러집니다.
        _generalTeams =
            uniqueAllTeams.where((t) => !_managedTeams.contains(t)).toList();

        // 선택 상태 초기화
        _selectedGeneralTeam = null;
        _selectedManagedTeam = null;
      });

      print('--- [DB 중복 방어 분리 완료] ---');
      print('전체 고유 팀 목록: $uniqueAllTeams');
      print('일반 팀 목록: $_generalTeams');
      print('관리 팀 목록: $_managedTeams');
    } catch (e) {
      print('팀 분리 매핑 로드 실패: $e');
    }
  }

  // 3️⃣ 💡 [스위칭 API 연동] 일반 -> 관리자로 격상 전송 ( > 버튼 )
  Future<void> _promoteToAdmin() async {
    if (_selectedEmployee == null || _selectedGeneralTeam == null) return;
    try {
      await ApiClient().dio.put(
        '/api/admin/employees/${_selectedEmployee!.employeeNumber}',
        data: {
          'name': _selectedEmployee!.name,
          'email': _selectedEmployee!.email ?? '',
          'department': _selectedEmployee!.department,
          'team': _selectedEmployee!.team,
          'position': _selectedEmployee!.position,
          'hireDate': _selectedEmployee!.hireDate,
          'role': 'ADMIN', // 관리자 권한 부여 명시
          'targetTeamsForRoleSwap': _changedTeams, // 🎯 타겟 팀명 강제 바인딩
        },
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('관리자 팀 임명이 반영되었습니다.')));
      _fetchEmployees(); // 전체 목록 리프레시를 통해 동기화
    } catch (e) {
      print('격상 에러: $e');
    }
  }

// 4️⃣ [스위칭 API 연동] 관리자 -> 일반으로 강등 전송 ( < 버튼 )
  Future<void> _demoteToGeneral() async {
    if (_selectedEmployee == null || _selectedManagedTeam == null) return;
    try {
      await ApiClient().dio.put(
        '/api/admin/employees/${_selectedEmployee!.employeeNumber}',
        data: {
          'name': _selectedEmployee!.name,
          'email': _selectedEmployee!.email ?? '',
          'department': _selectedEmployee!.department,
          'team': _selectedEmployee!.team,
          'position': _selectedEmployee!.position,
          'hireDate': _selectedEmployee!.hireDate,
          'role': 'EMPLOYEE', // 일반 멤버 권한으로 변경 명시
          'targetTeamsForRoleSwap': _changedTeams, // 해제할 팀명 바인딩
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 팀 매핑이 제거되었습니다.')),
      );
      _fetchEmployees(); // 전체 목록 및 상태 새로고침
    } catch (e) {
      print('강등 에러: $e');
    }
  }

  void toggleChangedTeam(String team) {
    setState(() {
      if (!_changedTeams.remove(team)) {
        _changedTeams.add(team);
      }
    });
  }

  // 3️⃣ [로컬 상태 변경] 일반 -> 관리자로 이동 ( > 버튼 )
  void _moveToAdmin() {
    if (_selectedGeneralTeam == null) return;
    setState(() {
      final team = _selectedGeneralTeam!;
      _generalTeams.remove(team);

      // 중복 방지를 위해 확인 후 추가
      if (!_managedTeams.contains(team)) {
        _managedTeams.add(team);
      }
      _selectedGeneralTeam = null;
      toggleChangedTeam(team);
    });
  }

  // 4️⃣ [로컬 상태 변경] 관리자 -> 일반으로 이동 ( < 버튼 )
  void _moveToGeneral() {
    if (_selectedManagedTeam == null) return;
    setState(() {
      final team = _selectedManagedTeam!;
      _managedTeams.remove(team);

      // 중복 방지를 위해 확인 후 추가
      if (!_generalTeams.contains(team)) {
        _generalTeams.add(team);
      }
      _selectedManagedTeam = null;
      toggleChangedTeam(team);
    });
  }

  // 5️⃣ [서버 전송] 최하단 저장 버튼을 누를 때 한 번에 백엔드로 전송하는 함수
  Future<void> _saveChanges() async {
    if (_selectedEmployee == null) return;
    setState(() => _isLoading = true);

    try {
      await ApiClient().dio.put(
        '/api/admin/employees/${_selectedEmployee!.employeeNumber}',
        data: {
          'name': _selectedEmployee!.name,
          'email': _selectedEmployee!.email ?? '',
          'department': _selectedEmployee!.department,
          'team': _selectedEmployee!.team,
          'position': _selectedEmployee!.position,
          'hireDate': _selectedEmployee!.hireDate,
          'targetTeamsForRoleSwap': _changedTeams.toList(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한 설정 변경 사항이 성공적으로 저장되었습니다.')),
      );

      _fetchEmployees(); // 완료 후 리스트 리프레시
    } catch (e) {
      print('권한 설정 저장 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했습니다.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자 설정')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                // 💡 Row를 Column으로 감싸서 하단 공간을 확보합니다.
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // 📄 [왼쪽 컬럼] 사용자 (이름/아이디)
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: '사용자 목록',
                            child: ListView.builder(
                              itemCount: _employees.length,
                              itemBuilder: (context, index) {
                                final emp = _employees[index];
                                final isSelected =
                                    _selectedEmployee?.employeeNumber ==
                                        emp.employeeNumber;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFFFFDAB9),
                                            width: 2.0)
                                        : null,
                                  ),
                                  child: ListTile(
                                    selected: isSelected,
                                    selectedTileColor: Colors.transparent,
                                    // 🎯 title 영역 하나에 Column을 넣어 세 줄로 정렬합니다.
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start, // 왼쪽 정렬
                                      children: [
                                        // 1. 이름
                                        Text(
                                          emp.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected
                                                ? const Color(0xFFE97451)
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: 4), // 텍스트 사이 간격 조정

                                        // 2. 직급
                                        Text(
                                          emp.position,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFFF4A460)
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // 3. 사번
                                        Text(
                                          emp.employeeNumber,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? const Color(0xFFF4A460)
                                                : Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),

                                    onTap: () {
                                      setState(() {
                                        _selectedEmployee = emp;
                                      });
                                      _fetchEmployeeTeams();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 📄 [중앙 컬럼] 일반 팀 목록
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: '일반팀 목록',
                            child: ListView.builder(
                              itemCount: _generalTeams.length,
                              itemBuilder: (context, index) {
                                final team = _generalTeams[index];
                                final isSelected = _selectedGeneralTeam == team;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.orange.shade50,
                                  title: Text(team,
                                      style: const TextStyle(fontSize: 14)),
                                  onTap: () {
                                    setState(() {
                                      _selectedGeneralTeam = team;
                                      _selectedManagedTeam = null;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),

                        // 📄 [중앙 화살표 제어부] < > 제어 컨트롤러 버튼 영역
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _selectedGeneralTeam != null
                                    ? _moveToAdmin
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F3A5F),
                                    padding: const EdgeInsets.all(12)),
                                child: const Icon(Icons.chevron_right,
                                    color: Colors.white),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _selectedManagedTeam != null
                                    ? _moveToGeneral
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.all(12)),
                                child: const Icon(Icons.chevron_left,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // 📄 [우측 컬럼] 관리자 팀 목록
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: '관리팀 목록',
                            child: ListView.builder(
                              itemCount: _managedTeams.length,
                              itemBuilder: (context, index) {
                                final team = _managedTeams[index];
                                final isSelected = _selectedManagedTeam == team;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.green.shade50,
                                  title: Text(team,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green)),
                                  onTap: () {
                                    setState(() {
                                      _selectedManagedTeam = team;
                                      _selectedGeneralTeam = null;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🎯 화면 최하단 우측 정렬 저장 버튼 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            _selectedEmployee != null ? _saveChanges : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F3A5F),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          '변경 사항 저장하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )),
    );
  }

  // 외곽 아웃라인 테두리 가이드 패널 빌더
  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      // 📄 기존 decoration: BoxDecoration(...) 아랫줄부터 이어서 붙여넣으세요.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
} // 💡 State 클래스를 완전히 종료하는 마지막 중괄호입니다.
