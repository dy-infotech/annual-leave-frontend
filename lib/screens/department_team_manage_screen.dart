import 'package:flutter/material.dart';

import '../models/department_team_models.dart';
import '../models/employee.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/employee_picker_dialog.dart';

/// 부서 및 팀 관리 화면.
///
/// 한 화면 안에서 '부서' / '팀' 두 탭으로 나누어 각각 조회·추가·수정을 제공한다.
/// 팀은 관리자를 최소 1명 지정해야 저장할 수 있다(백엔드 team.project_manager_id NOT NULL).
///
/// 주의: 부서/팀 CRUD API 는 백엔드에 아직 없다(2026-08 기준).
/// 목록 조회는 /api/admin/auth/common 으로 폴백하여 화면이 뜨도록 했고,
/// 추가·수정은 아래 추정 경로를 호출한다. 백엔드 확정 후 경로를 맞출 것.
///   GET  /api/admin/departments
///   POST /api/admin/departments
///   PUT  /api/admin/departments/{departmentId}
///   GET  /api/admin/teams
///   POST /api/admin/teams
///   PUT  /api/admin/teams/{teamId}
class DepartmentTeamManageScreen extends StatefulWidget {
  const DepartmentTeamManageScreen({super.key});

  @override
  State<DepartmentTeamManageScreen> createState() =>
      _DepartmentTeamManageScreenState();
}

class _DepartmentTeamManageScreenState extends State<DepartmentTeamManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _deptScrollController = ScrollController();
  final _teamScrollController = ScrollController();

  List<Department> _departments = [];
  List<Team> _teams = [];

  // 탭별로 목록이 독립적이므로 로딩/에러 상태도 탭별로 분리한다.
  bool _isDeptLoading = false;
  bool _isTeamLoading = false;
  String? _deptError;
  String? _teamError;

  /// 목록 조회가 폴백(이름만 조회)으로 떨어졌는지. 이 경우 id 가 없어 수정할 수 없다.
  bool _deptFallback = false;
  bool _teamFallback = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDepartments();
    _fetchTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deptScrollController.dispose();
    _teamScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 조회

  // 1. 부서 목록 조회
  Future<void> _fetchDepartments() async {
    setState(() {
      _isDeptLoading = true;
      _deptError = null;
    });

    try {
      final response = await ApiClient().dio.get('/api/admin/departments');
      final fetched = (response.data as List)
          .map((json) => Department.fromJson(json))
          .toList();

      if (!mounted) return;
      setState(() {
        _departments = fetched;
        _deptFallback = false;
      });
    } catch (e) {
      debugPrint('부서 목록 조회 실패, 공통 코드로 폴백: $e');
      await _fetchDepartmentsFromCommon();
    } finally {
      if (mounted) setState(() => _isDeptLoading = false);
    }
  }

  /// 부서 CRUD API 가 없을 때의 폴백. 이름만 얻을 수 있어 수정은 불가능하다.
  Future<void> _fetchDepartmentsFromCommon() async {
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;
      final names = List<String>.from(data['department'] ?? []);

      if (!mounted) return;
      setState(() {
        _departments = names.map((name) => Department.fromName(name)).toList();
        _deptFallback = true;
      });
    } catch (e) {
      debugPrint('부서 공통 코드 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _departments = [];
        _deptError = '부서 목록 조회에 실패했습니다.';
      });
    }
  }

  // 2. 팀 목록 조회
  Future<void> _fetchTeams() async {
    setState(() {
      _isTeamLoading = true;
      _teamError = null;
    });

    try {
      final response = await ApiClient().dio.get('/api/admin/teams');
      final fetched =
          (response.data as List).map((json) => Team.fromJson(json)).toList();

      if (!mounted) return;
      setState(() {
        _teams = fetched;
        _teamFallback = false;
      });
    } catch (e) {
      debugPrint('팀 목록 조회 실패, 공통 코드로 폴백: $e');
      await _fetchTeamsFromCommon();
    } finally {
      if (mounted) setState(() => _isTeamLoading = false);
    }
  }

  /// 팀 CRUD API 가 없을 때의 폴백. 관리자 정보는 얻을 수 없다.
  Future<void> _fetchTeamsFromCommon() async {
    try {
      final response = await ApiClient().dio.get('/api/admin/auth/common');
      final data = response.data as Map<String, dynamic>;
      // 배포된 서버는 accessibleTeam, 로컬 백엔드는 team 으로 내려준다.
      final names =
          List<String>.from(data['accessibleTeam'] ?? data['team'] ?? []);

      if (!mounted) return;
      setState(() {
        _teams = names.map((name) => Team.fromName(name)).toList();
        _teamFallback = true;
      });
    } catch (e) {
      debugPrint('팀 공통 코드 조회 실패: $e');
      if (!mounted) return;
      setState(() {
        _teams = [];
        _teamError = '팀 목록 조회에 실패했습니다.';
      });
    }
  }

  // ---------------------------------------------------------------- 저장

  // 3. 부서 등록/수정
  Future<void> _saveDepartment(Department? origin, String name) async {
    final isEdit = origin != null;
    setState(() => _isDeptLoading = true);

    try {
      final body = DepartmentSaveRequest(departmentName: name).toJson();
      final response = isEdit
          ? await ApiClient()
              .dio
              .put('/api/admin/departments/${origin.departmentId}', data: body)
          : await ApiClient().dio.post('/api/admin/departments', data: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar(isEdit ? '부서가 수정되었습니다.' : '부서가 등록되었습니다.');
        await _fetchDepartments();
      } else {
        _showSnackBar(isEdit ? '부서 수정에 실패했습니다.' : '부서 등록에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('부서 저장 실패: $e');
      _showSnackBar(isEdit ? '부서 수정에 실패했습니다.' : '부서 등록에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isDeptLoading = false);
    }
  }

  // 4. 팀 등록/수정
  Future<void> _saveTeam(
    Team? origin,
    String name,
    String? parentTeam,
    List<TeamManager> managers,
  ) async {
    final isEdit = origin != null;
    setState(() => _isTeamLoading = true);

    try {
      final body = TeamSaveRequest(
        teamName: name,
        parentTeam: parentTeam,
        managerEmployeeNumbers:
            managers.map((m) => m.employeeNumber).toList(),
      ).toJson();

      final response = isEdit
          ? await ApiClient()
              .dio
              .put('/api/admin/teams/${origin.teamId}', data: body)
          : await ApiClient().dio.post('/api/admin/teams', data: body);

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar(isEdit ? '팀이 수정되었습니다.' : '팀이 등록되었습니다.');
        await _fetchTeams();
      } else {
        _showSnackBar(isEdit ? '팀 수정에 실패했습니다.' : '팀 등록에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('팀 저장 실패: $e');
      _showSnackBar(isEdit ? '팀 수정에 실패했습니다.' : '팀 등록에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isTeamLoading = false);
    }
  }

  // ---------------------------------------------------------------- 다이얼로그

  // 5. 부서 추가/수정 다이얼로그 (department 가 null 이면 추가 모드)
  Future<void> _showDepartmentDialog({Department? department}) async {
    final isEdit = department != null;
    final controller =
        TextEditingController(text: department?.departmentName ?? '');
    String? nameError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isEdit ? '부서 수정' : '부서 추가',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '부서명',
                errorText: nameError,
              ),
              onChanged: (_) {
                if (nameError != null) {
                  setDialogState(() => nameError = null);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => nameError = '부서명을 입력해 주세요.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                isEdit ? '수정' : '등록',
                style: const TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final name = controller.text.trim();
    controller.dispose();

    if (confirmed == true) {
      await _saveDepartment(department, name);
    }
  }

  // 6. 팀 추가/수정 다이얼로그 (team 이 null 이면 추가 모드)
  Future<void> _showTeamDialog({Team? team}) async {
    final isEdit = team != null;
    final controller = TextEditingController(text: team?.teamName ?? '');

    // 상위 팀 후보: 기존 팀 이름(중복 제거). 수정 모드에서는 자기 자신을 제외한다.
    final parentCandidates = _teams
        .map((t) => t.teamName)
        .where((n) => n.isNotEmpty && n != team?.teamName)
        .toSet()
        .toList()
      ..sort();

    String? selectedParent =
        parentCandidates.contains(team?.parentTeam) ? team?.parentTeam : null;
    final selectedManagers = List<TeamManager>.from(team?.managers ?? const []);

    String? nameError;
    String? managerError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isEdit ? '팀 수정' : '팀 추가',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      labelText: '팀명',
                      errorText: nameError,
                    ),
                    onChanged: (_) {
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedParent,
                    decoration: const InputDecoration(labelText: '상위 팀'),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    items: parentCandidates
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedParent = value),
                  ),
                  const SizedBox(height: 16),
                  _buildManagerSection(
                    setDialogState: setDialogState,
                    dialogContext: dialogContext,
                    selectedManagers: selectedManagers,
                    managerError: managerError,
                    clearManagerError: () => managerError = null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  setDialogState(() => nameError = '팀명을 입력해 주세요.');
                  return;
                }
                // 팀 관리자는 최소 1명 필수 (백엔드 project_manager_id NOT NULL)
                if (selectedManagers.isEmpty) {
                  setDialogState(
                      () => managerError = '팀 관리자를 최소 1명 지정해 주세요.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                isEdit ? '수정' : '등록',
                style: const TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final name = controller.text.trim();
    controller.dispose();

    if (confirmed == true) {
      await _saveTeam(team, name, selectedParent, selectedManagers);
    }
  }

  /// 팀 다이얼로그 안의 관리자 지정 영역.
  Widget _buildManagerSection({
    required StateSetter setDialogState,
    required BuildContext dialogContext,
    required List<TeamManager> selectedManagers,
    required String? managerError,
    required VoidCallback clearManagerError,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '팀 관리자',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            const Text(
              '(최소 1명)',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final picked = await showDialog<Employee>(
                  context: dialogContext,
                  builder: (_) => EmployeePickerDialog(
                    title: '팀 관리자 선택',
                    excludeEmployeeNumbers: selectedManagers
                        .map((m) => m.employeeNumber)
                        .toList(),
                  ),
                );
                if (picked == null) return;
                setDialogState(() {
                  selectedManagers.add(TeamManager(
                    employeeNumber: picked.employeeNumber,
                    name: picked.name,
                    position: picked.position,
                  ));
                  clearManagerError();
                });
              },
              child: const Text(
                '+ 추가',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (managerError != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              managerError,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        if (selectedManagers.isEmpty)
          const Text(
            '지정된 관리자가 없습니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedManagers
                .map((m) => _buildManagerChip(
                      manager: m,
                      onRemove: () => setDialogState(
                          () => selectedManagers.remove(m)),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildManagerChip({
    required TeamManager manager,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.slate.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            manager.display,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppColors.slate),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('부서 및 팀 관리'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.slate,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.slate,
          tabs: const [Tab(text: '부서'), Tab(text: '팀')],
        ),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [_buildDepartmentTab(), _buildTeamTab()],
        ),
      ),
    );
  }

  // 7. 부서 관리 탭 화면
  Widget _buildDepartmentTab() {
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '부서 추가',
          count: _departments.length,
          onAdd: _isDeptLoading ? null : () => _showDepartmentDialog(),
        ),
        if (_deptFallback) _buildFallbackNotice('부서'),
        _buildErrorSection(_deptError),
        Expanded(
          child: _buildListArea(
            isLoading: _isDeptLoading,
            isEmpty: _departments.isEmpty,
            emptyMessage: '등록된 부서가 없습니다.',
            scrollController: _deptScrollController,
            itemCount: _departments.length,
            itemBuilder: (context, index) =>
                _buildDepartmentItem(_departments[index]),
          ),
        ),
      ],
    );
  }

  // 8. 팀 관리 탭 화면
  Widget _buildTeamTab() {
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '팀 추가',
          count: _teams.length,
          onAdd: _isTeamLoading ? null : () => _showTeamDialog(),
        ),
        if (_teamFallback) _buildFallbackNotice('팀'),
        _buildErrorSection(_teamError),
        Expanded(
          child: _buildListArea(
            isLoading: _isTeamLoading,
            isEmpty: _teams.isEmpty,
            emptyMessage: '등록된 팀이 없습니다.',
            scrollController: _teamScrollController,
            itemCount: _teams.length,
            itemBuilder: (context, index) => _buildTeamItem(_teams[index]),
          ),
        ),
      ],
    );
  }

  /// 탭 상단의 추가 버튼 + 건수 표기.
  Widget _buildTabHeader({
    required String addLabel,
    required int count,
    required VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: Text(addLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F3A5F),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Text(
            '$count건',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  /// 목록이 폴백 경로로 조회됐을 때의 안내. 이 상태에서는 수정이 불가능하다.
  Widget _buildFallbackNotice(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label 관리 API가 아직 준비되지 않아 이름만 조회했습니다. 수정은 사용할 수 없습니다.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }

  /// 로딩 / 빈 목록 / 리스트 3분기를 담당하는 공통 영역.
  Widget _buildListArea({
    required bool isLoading,
    required bool isEmpty,
    required String emptyMessage,
    required ScrollController scrollController,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slate),
      );
    }

    if (isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(Colors.black.withOpacity(0.3)),
          thickness: const WidgetStatePropertyAll(5),
          radius: const Radius.circular(8),
        ),
      ),
      child: Scrollbar(
        controller: scrollController,
        interactive: true,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }

  Widget _buildDepartmentItem(Department dept) {
    final editable = dept.isEditable;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: editable
          ? () => _showDepartmentDialog(department: dept)
          : () => _showSnackBar('부서 수정 기능은 준비 중입니다.'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dept.departmentName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (dept.teamCount != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '팀 ${dept.teamCount}개',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: editable ? AppColors.textMuted : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamItem(Team team) {
    final editable = team.isEditable;
    final managerText = team.managers.isEmpty
        ? '관리자 미지정'
        : team.managers.map((m) => m.display).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: editable
          ? () => _showTeamDialog(team: team)
          : () => _showSnackBar('팀 수정 기능은 준비 중입니다.'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    team.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (team.managers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '관리자 ${team.managers.length}명',
                      style: const TextStyle(
                        color: AppColors.sage,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: editable ? AppColors.textMuted : AppColors.divider,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              managerText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (team.parentTeam != null && team.parentTeam!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '상위 팀 · ${team.parentTeam}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
