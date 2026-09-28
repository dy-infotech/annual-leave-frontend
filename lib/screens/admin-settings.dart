import 'package:dio/dio.dart';
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
  bool _needsReconcile = false;
  int _teamLoadSeq = 0;

  final TextEditingController _employeeInfoController =
      TextEditingController(); //사용자 이름
  final ScrollController _employeeScrollController =
      ScrollController(); //스크롤 컨트롤러

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  @override
  void dispose() {
    //스크롤 해제
    _employeeScrollController.dispose();
    super.dispose();
  }

  // 1️⃣ 사원 전체 목록 로드 (왼쪽 컬럼용)
  Future<void> _fetchEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient().dio.get('/api/admin/employees/all');
      final List<Employee> fetched = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .toList();

      if (!mounted) return;
      final previousNumber = _selectedEmployee?.employeeNumber;
      Employee? selected;
      if (fetched.isNotEmpty) {
        // 기본 첫 사원 자동 선택
        selected = previousNumber == null
            ? fetched.first
            : fetched.firstWhere(
                (employee) => employee.employeeNumber == previousNumber,
                orElse: () => fetched.first,
              );
      }

      setState(() {
        _employees = fetched;
        _selectedEmployee = selected;
        if (selected != null) {
          _employeeInfoController.text =
              '${selected.name} ${selected.position} ${selected.employeeNumber}';
        }
      });

      if (selected != null) {
        await _fetchEmployeeTeams();
      }
    } catch (e) {
      //  print('사원 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2️⃣ 선택된 사원의 '일반 팀' 및 '관리자 팀' 분리 로드
  Future<bool> _fetchEmployeeTeams() async {
    final selected = _selectedEmployee;
    if (selected == null) return false;
    final seq = ++_teamLoadSeq;

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
      // 첫 번째는 깔끔하게 원본 이름 유지 (또는 일괄적으로 '팀명 (1)' 형식을 맞춰도 됨)
      // v2에서는 팀명이 UNIQUE이므로 위 legacy 표시 변환을 적용하지 않고 원본 이름을 그대로 사용한다.
      final List<String> allTeams = rawAllTeams.toSet().toList();

      // 🎯 1. 사용자의 권한 역할(Role) 파싱
      final String currentRole = (selected.role ?? '').toUpperCase();
      final bool isAdmin = currentRole == 'ADMIN' || currentRole == 'MANAGER';

      // 🎯 2. 관리자('ADMIN')인 경우 사원의 teamList 매핑 구성
      // 사원 정보에 들어있는 원본 팀명 목록들
      // 사원이 가진 원본 이름을 위에서 만든 고유 변환 이름 목록(uniqueAllTeams)과 매핑하여 순서대로 할당
      // 이를 통해 DB에 중복 저장된 이름 개수만큼 순서대로 관리팀에 채워 넣습니다.
      // uniqueAllTeams 중에서 해당 원본 이름으로 시작하는 유니크 이름을 찾아서 추가
      final managedTeamNames =
          isAdmin ? (selected.teamList ?? const <String>[]).toSet() : <String>{};

      if (!mounted ||
          seq != _teamLoadSeq ||
          _selectedEmployee?.employeeNumber != selected.employeeNumber) {
        return false;
      }

      setState(() {
        // 🎯 3. 최종 할당 및 중복 없는 필터링
        _managedTeams =
            allTeams.where((team) => managedTeamNames.contains(team)).toList();

        // 고유 문자열 구조이므로 이제 명확하게 걸러집니다.
        _generalTeams =
            allTeams.where((team) => !managedTeamNames.contains(team)).toList();

        // 선택 상태 초기화
        _selectedGeneralTeam = null;
        _selectedManagedTeam = null;
      });

      print('--- [팀 권한 분리 완료] ---');
      print('전체 팀 목록: $allTeams');
      print('일반 팀 목록: $_generalTeams');
      print('관리 팀 목록: $_managedTeams');
      return true;
    } catch (e) {
      print('팀 분리 매핑 로드 실패: $e');
      return false;
    }
  }

  void _selectEmployee(Employee next) {
    if (_isLoading || _needsReconcile) return;
    if (_selectedEmployee?.employeeNumber == next.employeeNumber) return;

    if (_changedTeams.isNotEmpty) {
      final current = _selectedEmployee;
      if (current != null) {
        _employeeInfoController.text =
            '${current.name} ${current.position} ${current.employeeNumber}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재 직원의 변경사항을 저장한 뒤 다른 직원을 선택해 주세요.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedEmployee = next;
      _changedTeams.clear();
      _generalTeams = [];
      _managedTeams = [];
      _selectedGeneralTeam = null;
      _selectedManagedTeam = null;
      _employeeInfoController.text =
          '${next.name} ${next.position} ${next.employeeNumber}';
    });
    _fetchEmployeeTeams();
  }

  Future<bool> _reloadSelectedFromServer(String employeeNumber) async {
    try {
      final response = await ApiClient().dio.get(
        '/api/admin/employees/all',
        queryParameters: {'searchParam': employeeNumber},
      );
      final fetched = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .where((employee) => employee.employeeNumber == employeeNumber)
          .toList();
      if (fetched.isEmpty || !mounted) return false;

      final current = fetched.first;
      setState(() {
        _selectedEmployee = current;
        _employees = _employees
            .map((employee) => employee.employeeNumber == employeeNumber
                ? current
                : employee)
            .toList();
        _generalTeams = [];
        _managedTeams = [];
        _selectedGeneralTeam = null;
        _selectedManagedTeam = null;
        _employeeInfoController.text =
            '${current.name} ${current.position} ${current.employeeNumber}';
      });

      final teamsLoaded = await _fetchEmployeeTeams();
      if (!teamsLoaded || !mounted) return false;

      setState(() {
        _changedTeams.clear();
        _needsReconcile = false;
      });
      return true;
    } catch (e) {
      print('선택 직원 서버 상태 재조회 실패: $e');
      return false;
    }
  }

  Future<void> _reconcileSelected() async {
    final employee = _selectedEmployee;
    if (_isLoading || employee == null) return;

    setState(() => _isLoading = true);
    final reloaded = await _reloadSelectedFromServer(employee.employeeNumber);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _needsReconcile = !reloaded;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reloaded
              ? '서버의 현재 상태를 다시 불러왔습니다.'
              : '서버 상태를 불러오지 못했습니다. 다시 시도해 주세요.'),
        ),
      );
    }
  }

  // 3️⃣ 💡 [스위칭 API 연동] 일반 -> 관리자로 격상 전송
  /* Future<void> _promoteToAdmin() async {
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

// 4️⃣ [스위칭 API 연동] 관리자 -> 일반으로 강등 전송 
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
  } */

  void toggleChangedTeam(String team) {
    setState(() {
      if (!_changedTeams.remove(team)) {
        _changedTeams.add(team);
      }
    });
  }

  // 3️⃣ [로컬 상태 변경] 일반 -> 관리자로 이동 ( > 버튼 )
  void _moveToAdmin() {
    if (_needsReconcile || _isLoading || _selectedGeneralTeam == null) return;
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
    if (_needsReconcile || _isLoading || _selectedManagedTeam == null) return;
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

  bool _isAmbiguousWriteFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    return error.response == null ||
        statusCode == 408 ||
        (statusCode != null && statusCode >= 500);
  }

  Map<String, dynamic> _roleSwapBody(
      Employee employee, List<String> managedTeams) {
    return {
      'name': employee.name,
      'email': employee.email ?? '',
      'department': employee.department,
      'team': employee.team,
      'position': employee.position,
      'hireDate': employee.hireDate,
      'fireDate': employee.fireDate,
      // 변경 목록(toggle)이 아니라 현재 화면의 최종 관리팀 상태를 전송한다.
      // 동일 요청이 재전송되어도 Backend desired-state PUT이 같은 결과로 수렴한다.
      'managedTeams': managedTeams,
    };
  }

  // 5️⃣ [서버 전송] 최하단 저장 버튼을 누를 때 한 번에 백엔드로 전송하는 함수
  Future<void> _saveChanges() async {
    final employee = _selectedEmployee;
    if (_isLoading ||
        _needsReconcile ||
        employee == null ||
        _changedTeams.isEmpty) {
      return;
    }

    final managedTeams = List<String>.from(_managedTeams);
    setState(() => _isLoading = true);

    try {
      await ApiClient().dio.put(
        '/api/admin/employees/${employee.employeeNumber}',
        data: _roleSwapBody(employee, managedTeams),
      );

      /* ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한 설정 변경 사항이 성공적으로 저장되었습니다.')),
      ); */
      // 기존에는 _fetchEmployees(); // 완료 후 리스트 리프레시를 통해 동기화
      // 를 호출했지만 현재는 선택 직원을 유지한 채 서버 상태를 재조회한다.
      final reloaded =
          await _reloadSelectedFromServer(employee.employeeNumber);
      if (!reloaded && mounted) {
        setState(() => _needsReconcile = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장은 완료됐지만 최신 상태를 다시 불러오지 못했습니다. 서버 상태를 재조회해 주세요.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final resultUnknown = _isAmbiguousWriteFailure(e);
      if (resultUnknown) {
        setState(() => _needsReconcile = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultUnknown
              ? '저장 결과를 확인하지 못했습니다. 서버 상태를 재조회한 뒤 다시 편집해 주세요.'
              : (e.message ?? '저장 중 오류가 발생했습니다.')),
        ),
      );
    } catch (e) {
      print('권한 설정 저장 실패: $e');
      if (!mounted) return;
      setState(() => _needsReconcile = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장 결과를 확인하지 못했습니다. 서버 상태를 재조회한 뒤 다시 편집해 주세요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('관리자별 관리팀 설정')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                // 💡 Row를 Column으로 감싸서 하단 공간을 확보합니다.
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // 📄 [왼쪽 컬럼] 사용자 (이름/아이디)
                        Expanded(
                          flex: 3,
                          child: _buildPanel(
                            title: '사용자 선택',
                            child: ListView.builder(
                              controller: _employeeScrollController,
                              itemCount: _employees.length,
                              itemBuilder: (context, index) {
                                final emp = _employees[index];
                                final isSelected =
                                    _selectedEmployee?.employeeNumber ==
                                        emp.employeeNumber;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 0, // 🔽 리스트 간 간격 제거
                                  ),
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
                                    dense: true, // 🔥 높이 축소
                                    visualDensity: const VisualDensity(
                                      vertical: -4, // 🔥 세로 간격 축소
                                    ),
                                    title: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
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
                                        const SizedBox(width: 6),
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
                                        const SizedBox(width: 6),
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
                                    onTap: () => _selectEmployee(emp),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [중앙 컬럼] 일반 팀 목록
                        Expanded(
                          flex: 4,
                          child: _buildPanel(
                            title: '팀 목록',
                            child: ListView.builder(
                              itemCount: _generalTeams.length,
                              itemBuilder: (context, index) {
                                final team = _generalTeams[index];
                                final isSelected = _selectedGeneralTeam == team;

                                return GestureDetector(
                                  onDoubleTap: () {
                                    setState(() {
                                      _selectedGeneralTeam = team;
                                      _selectedManagedTeam = null;
                                    });
                                    if (_selectedGeneralTeam != null) {
                                      _moveToAdmin();
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFFFFDAB9),
                                              width: 2.0,
                                            )
                                          : null,
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      visualDensity: const VisualDensity(
                                        vertical: -4,
                                      ),
                                      selected: isSelected,
                                      selectedTileColor: Colors.orange.shade50,
                                      title: Text(
                                        team,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected
                                              ? const Color(0xFFE97451)
                                              : Colors.black87,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedGeneralTeam = team;
                                          _selectedManagedTeam = null;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [중앙 화살표 제어부] 컨트롤러 버튼 영역
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _selectedGeneralTeam != null
                                    ? _moveToAdmin
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(36, 36), // 버튼 크기
                                    backgroundColor: const Color(0xFF1F3A5F),
                                    padding: const EdgeInsets.all(8)),
                                child: const Icon(
                                    Icons.keyboard_double_arrow_down_sharp,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _selectedManagedTeam != null
                                    ? _moveToGeneral
                                    : null,
                                style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(36, 36), // 버튼 크
                                    backgroundColor: Colors.grey.shade700,
                                    padding: const EdgeInsets.all(8)),
                                child: const Icon(
                                    Icons.keyboard_double_arrow_up_sharp,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 📄 [우측 컬럼] 관리자 팀 목록
                        Expanded(
                          flex: 4,
                          child: _buildPanel(
                            title: '관리팀',
                            child: ListView.builder(
                              itemCount: _managedTeams.length,
                              itemBuilder: (context, index) {
                                final team = _managedTeams[index];
                                final isSelected = _selectedManagedTeam == team;
                                return GestureDetector(
                                  onDoubleTap: () {
                                    setState(() {
                                      _selectedManagedTeam = team;
                                      _selectedGeneralTeam = null;
                                    });
                                    // 두 번 탭 이벤트 처리
                                    if (_selectedManagedTeam != null) {
                                      _moveToGeneral();
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 0, // 🔽 리스트 간 간격 제거
                                    ),
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
                                      dense: true, // 🔥 높이 축소
                                      visualDensity: const VisualDensity(
                                        vertical: -4, // 🔥 세로 간격 축소
                                      ),
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
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🎯 화면 최하단 우측 정렬 저장 버튼 영역
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_needsReconcile) ...[
                        OutlinedButton.icon(
                          onPressed: _selectedEmployee != null
                              ? _reconcileSelected
                              : null,
                          icon: const Icon(Icons.refresh),
                          label: const Text('서버 상태 다시 조회'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: _selectedEmployee != null &&
                                _changedTeams.isNotEmpty &&
                                !_needsReconcile
                            ? _saveChanges
                            : null,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  if (title == "사용자 선택") ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: TextField(
                          controller: _employeeInfoController,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: '사용자 이름 입력 또는 선택',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onChanged: _selectEmployeeByName,
                        ),
                      ),
                    ),
                  ],
                ],
              )),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _selectEmployeeByName(String value) {
    final keyword = value.trim();

    final index = _employees.indexWhere(
      (e) => e.name == keyword,
    );

    if (index == -1) return;

    _selectEmployee(_employees[index]);

    if (_selectedEmployee?.employeeNumber ==
        _employees[index].employeeNumber) {
      _scrollToEmployee(index);
    }
  }

  void _scrollToEmployee(int index) {
    const double itemHeight = 35.0; // 한 행의 실제 높이에 맞게 조정

    _employeeScrollController.animateTo(
      index * itemHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
} // 💡 State 클래스를 완전히 종료하는 마지막 중괄호입니다.
