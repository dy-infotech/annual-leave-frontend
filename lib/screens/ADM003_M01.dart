// ADM003_M01: 부서 및 팀 관리 화면 (부서/팀 탭)
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/department_team_models.dart';
import '../models/employee.dart';
import '../services/department_team_api.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import '../widgets/employee_picker_dialog.dart';

// 부서 및 팀 관리 화면. (대표이사 전용)
//
// 한 화면 안에서 '부서' / '팀' 두 탭으로 나누어 각각 조회·추가·수정·삭제를 제공한다.
// 사용하는 API 는 docs/api-spec-department-team.md 참고.
//
// - 부서 탭: 부서 목록과 부서별 소속 팀을 함께 보여준다.
//   대표이사 부서는 백엔드가 수정·삭제를 막으므로 메뉴 자체를 노출하지 않는다.
// - 팀 탭: 부서 필터 칩 + 팀 카드(소속 부서·담당자·상위 팀)로 구성한다.
//   루트 팀(대표이사)은 상위 팀이 자기 자신이므로 상위 팀 변경과 삭제를 노출하지 않는다.
// - 입력은 모달 바텀시트로 받고, 서버가 거부한 사유(중복 이름 등)는 시트 안에 그대로 보여준다.

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

  /// 팀 탭의 부서 필터. null 이면 전체.
  int? _teamFilterDeptId;

  DepartmentTeamApi get _api => DepartmentTeamApi.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 탭 전환 시 FloatingActionButton 라벨을 바꾸기 위해 다시 그린다.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deptScrollController.dispose();
    _teamScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 조회

  Future<void> _refreshAll() =>
      Future.wait([_fetchDepartments(), _fetchTeams()]);

  // 1. 부서 목록 조회
  Future<void> _fetchDepartments() async {
    if (!mounted) return;
    setState(() {
      _isDeptLoading = true;
      _deptError = null;
    });

    try {
      final fetched = await _api.fetchDepartments();
      if (!mounted) return;
      setState(() => _departments = fetched);
    } catch (e) {
      debugPrint('부서 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() => _deptError = _messageOf(e, '부서 목록을 불러오지 못했습니다.'));
    } finally {
      if (mounted) setState(() => _isDeptLoading = false);
    }
  }

  // 2. 팀 목록 조회
  Future<void> _fetchTeams() async {
    if (!mounted) return;
    setState(() {
      _isTeamLoading = true;
      _teamError = null;
    });

    try {
      final fetched = await _api.fetchTeams();
      if (!mounted) return;
      setState(() {
        _teams = fetched;
        // 필터로 걸어둔 부서가 사라졌으면 전체로 되돌린다.
        if (_teamFilterDeptId != null &&
            !fetched.any((t) => t.departmentId == _teamFilterDeptId)) {
          _teamFilterDeptId = null;
        }
      });
    } catch (e) {
      debugPrint('팀 목록 조회 실패: $e');
      if (!mounted) return;
      setState(() => _teamError = _messageOf(e, '팀 목록을 불러오지 못했습니다.'));
    } finally {
      if (mounted) setState(() => _isTeamLoading = false);
    }
  }

  /// ApiClient 인터셉터가 응답 body 의 message 를 DioException.message 로 옮겨 둔다.
  /// 서버가 준 사유가 있으면 그것을 쓰고, 없으면 기본 문구를 쓴다.
  String _messageOf(Object error, String fallback) {
    if (error is DioException) {
      final message = error.message;
      if (message != null && message.trim().isNotEmpty) return message;
    }
    return fallback;
  }

  List<Team> _teamsOfDepartment(int departmentId) =>
      _teams.where((t) => t.departmentId == departmentId).toList();

  // ---------------------------------------------------------------- 부서 저장/삭제

  /// 부서 등록/이름 변경. 성공 시 null, 실패 시 시트에 보여줄 메시지를 반환한다.
  Future<String?> _submitDepartment(Department? origin, String name) async {
    try {
      if (origin == null) {
        await _api.createDepartment(name);
      } else {
        await _api.updateDepartment(origin.departmentId, name);
      }
      return null;
    } catch (e) {
      debugPrint('부서 저장 실패: $e');
      return _messageOf(
          e, origin == null ? '부서 등록에 실패했습니다.' : '부서 수정에 실패했습니다.');
    }
  }

  // 3. 부서 추가/수정 시트 (department 가 null 이면 추가 모드)
  Future<void> _openDepartmentSheet({Department? department}) async {
    final saved = await _showFormSheet<bool>(
      builder: (_) => _DepartmentFormSheet(
        department: department,
        onSubmit: (name) => _submitDepartment(department, name),
      ),
    );
    if (saved != true) return;
    _showSnackBar(department == null ? '부서가 등록되었습니다.' : '부서 이름이 변경되었습니다.');
    // 부서 이름은 팀 카드에도 표시되므로 두 목록을 함께 갱신한다.
    await _refreshAll();
  }

  // 4. 부서 삭제
  Future<void> _deleteDepartment(Department dept) async {
    final teamCount = _teamsOfDepartment(dept.departmentId).length;
    final confirmed = await _confirmDelete(
      title: '부서 삭제',
      message: teamCount > 0
          ? "'${dept.departmentName}' 부서에 소속 팀이 $teamCount개 있습니다.\n"
              '소속 팀을 먼저 정리해야 삭제할 수 있습니다.'
          : "'${dept.departmentName}' 부서를 삭제할까요?",
    );
    if (!confirmed) return;

    try {
      await _api.deleteDepartment(dept.departmentId);
      _showSnackBar('부서가 삭제되었습니다.');
      await _refreshAll();
    } catch (e) {
      debugPrint('부서 삭제 실패: $e');
      _showSnackBar(_messageOf(e, '부서 삭제에 실패했습니다.'));
    }
  }

  // ---------------------------------------------------------------- 팀 저장/삭제

  /// 팀 등록. 성공 시 null, 실패 시 시트에 보여줄 메시지를 반환한다.
  Future<String?> _submitTeamCreate(_TeamFormData data) async {
    try {
      await _api.createTeam(TeamCreateRequest(
        teamName: data.teamName,
        projectManagerId: data.managerId!,
        departmentId: data.departmentId!,
        parentTeamId: data.parentTeamId,
      ));
      return null;
    } catch (e) {
      debugPrint('팀 등록 실패: $e');
      return _messageOf(e, '팀 등록에 실패했습니다.');
    }
  }

  /// 팀 수정. 바뀐 필드만 보내고 나머지는 서버가 기존 값을 유지한다.
  Future<String?> _submitTeamUpdate(Team origin, _TeamFormData data) async {
    final request = TeamUpdateRequest(
      teamName: data.teamName != origin.teamName ? data.teamName : null,
      departmentId:
          data.departmentId != origin.departmentId ? data.departmentId : null,
      parentTeamId: data.parentTeamId != null &&
              data.parentTeamId != origin.parentTeamId
          ? data.parentTeamId
          : null,
      projectManagerId: data.managerId,
    );
    if (request.isEmpty) return null;

    try {
      await _api.updateTeam(origin.teamId, request);
      return null;
    } catch (e) {
      debugPrint('팀 수정 실패: $e');
      return _messageOf(e, '팀 수정에 실패했습니다.');
    }
  }

  // 5. 팀 추가/수정 시트 (team 이 null 이면 추가 모드)
  Future<void> _openTeamSheet({Team? team}) async {
    if (_departments.isEmpty) {
      _showSnackBar('부서 정보를 불러온 뒤 이용할 수 있습니다.');
      return;
    }

    final saved = await _showFormSheet<bool>(
      builder: (_) => _TeamFormSheet(
        team: team,
        departments: _departments,
        teams: _teams,
        onSubmit: (data) => team == null
            ? _submitTeamCreate(data)
            : _submitTeamUpdate(team, data),
      ),
    );
    if (saved != true) return;
    _showSnackBar(team == null ? '팀이 등록되었습니다.' : '팀이 수정되었습니다.');
    await _refreshAll();
  }

  // 6. 팀 삭제
  Future<void> _deleteTeam(Team team) async {
    final confirmed = await _confirmDelete(
      title: '팀 삭제',
      message: "'${team.teamName}' 팀을 삭제할까요?\n"
          '하위 팀이나 소속 사원이 있으면 삭제할 수 없으며,\n담당자(결재선) 정보도 함께 제거됩니다.',
    );
    if (!confirmed) return;

    try {
      await _api.deleteTeam(team.teamId);
      _showSnackBar('팀이 삭제되었습니다.');
      await _refreshAll();
    } catch (e) {
      debugPrint('팀 삭제 실패: $e');
      _showSnackBar(_messageOf(e, '팀 삭제에 실패했습니다.'));
    }
  }

  // ---------------------------------------------------------------- 공통 UI 유틸

  Future<T?> _showFormSheet<T>({required WidgetBuilder builder}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style:
                  TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final isLoading = _isDeptLoading || _isTeamLoading;
    final isDeptTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('부서 및 팀 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: isLoading ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.slate,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.slate,
          labelStyle:
              const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: _departments.isEmpty ? '부서' : '부서 ${_departments.length}'),
            Tab(text: _teams.isEmpty ? '팀' : '팀 ${_teams.length}'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading
            ? null
            : () => isDeptTab ? _openDepartmentSheet() : _openTeamSheet(),
        backgroundColor: AppColors.slate,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          isDeptTab ? '부서 추가' : '팀 추가',
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
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
    if (_isDeptLoading && _departments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slate),
      );
    }
    if (_deptError != null) {
      return _buildErrorState(_deptError!, _fetchDepartments);
    }
    if (_departments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.domain_outlined,
        message: '등록된 부서가 없습니다.',
        hint: '오른쪽 아래 버튼으로 첫 부서를 등록해 보세요.',
      );
    }

    return RefreshIndicator(
      color: AppColors.slate,
      onRefresh: _refreshAll,
      child: Scrollbar(
        controller: _deptScrollController,
        interactive: true,
        child: ListView.builder(
          controller: _deptScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: _departments.length,
          itemBuilder: (context, index) =>
              _buildDepartmentCard(_departments[index]),
        ),
      ),
    );
  }

  // 8. 팀 관리 탭 화면
  Widget _buildTeamTab() {
    if (_isTeamLoading && _teams.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slate),
      );
    }
    if (_teamError != null) {
      return _buildErrorState(_teamError!, _fetchTeams);
    }
    if (_teams.isEmpty) {
      return _buildEmptyState(
        icon: Icons.groups_outlined,
        message: '등록된 팀이 없습니다.',
        hint: '오른쪽 아래 버튼으로 첫 팀을 등록해 보세요.',
      );
    }

    final filtered = _teamFilterDeptId == null
        ? _teams
        : _teamsOfDepartment(_teamFilterDeptId!);

    return Column(
      children: [
        _buildDepartmentFilter(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.slate,
            onRefresh: _refreshAll,
            child: filtered.isEmpty
                ? _buildEmptyState(
                    icon: Icons.groups_outlined,
                    message: '이 부서에 소속된 팀이 없습니다.',
                    hint: '팀을 추가하거나 다른 부서를 선택해 보세요.',
                  )
                : Scrollbar(
                    controller: _teamScrollController,
                    interactive: true,
                    child: ListView.builder(
                      controller: _teamScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildTeamCard(filtered[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// 팀 탭 상단의 부서 필터 칩.
  Widget _buildDepartmentFilter() {
    Widget chip({
      required String label,
      required int count,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label $count'),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
          selectedColor: AppColors.slate,
          backgroundColor: AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.slate : AppColors.divider,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(
          children: [
            chip(
              label: '전체',
              count: _teams.length,
              selected: _teamFilterDeptId == null,
              onTap: () => setState(() => _teamFilterDeptId = null),
            ),
            ..._departments.map((dept) => chip(
                  label: dept.departmentName,
                  count: _teamsOfDepartment(dept.departmentId).length,
                  selected: _teamFilterDeptId == dept.departmentId,
                  onTap: () =>
                      setState(() => _teamFilterDeptId = dept.departmentId),
                )),
          ],
        ),
      ),
    );
  }

  // 9. 부서 카드 — 부서명과 소속 팀을 함께 보여준다.
  Widget _buildDepartmentCard(Department dept) {
    final teams = _teamsOfDepartment(dept.departmentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
              _buildIconTile(Icons.domain_rounded, AppColors.slate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            dept.departmentName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (dept.isProtected) ...[
                          const SizedBox(width: 6),
                          _buildBadge('기본', AppColors.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teams.isEmpty ? '소속 팀 없음' : '소속 팀 ${teams.length}개',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (dept.isProtected)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Tooltip(
                    message: '대표이사 부서는 수정·삭제할 수 없습니다.',
                    child: Icon(Icons.lock_outline,
                        size: 18, color: AppColors.textMuted),
                  ),
                )
              else
                _buildCardMenu(
                  editLabel: '이름 변경',
                  onEdit: () => _openDepartmentSheet(department: dept),
                  onDelete: () => _deleteDepartment(dept),
                ),
            ],
          ),
          if (teams.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: teams
                    .map((team) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            team.teamName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 10. 팀 카드 — 소속 부서·담당자·상위 팀을 모두 노출한다.
  Widget _buildTeamCard(Team team) {
    final managerText = team.managers.isEmpty
        ? '담당자 미지정'
        : team.managers
            .map((m) => '${m.display} (${m.employeeNumber})')
            .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
              _buildIconTile(Icons.groups_rounded, AppColors.sage),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.teamName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (team.isRoot) ...[
                      const SizedBox(width: 6),
                      _buildBadge('최상위', AppColors.sage),
                    ],
                  ],
                ),
              ),
              _buildCardMenu(
                editLabel: '팀 수정',
                onEdit: () => _openTeamSheet(team: team),
                // 루트 팀은 하위 팀 삭제 전엔 지울 수 없으므로 삭제 메뉴를 숨긴다.
                onDelete: team.isRoot ? null : () => _deleteTeam(team),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                _buildInfoRow('부서',
                    team.departmentName.isEmpty ? '미지정' : team.departmentName),
                const SizedBox(height: 5),
                _buildInfoRow(
                  '담당자',
                  managerText,
                  valueColor:
                      team.managers.isEmpty ? AppColors.coral : null,
                ),
                if (!team.isRoot &&
                    team.parentTeamName != null &&
                    team.parentTeamName!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _buildInfoRow('상위 팀', team.parentTeamName!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconTile(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 카드 우측의 ⋮ 메뉴. onDelete 가 null 이면 수정만 노출한다.
  Widget _buildCardMenu({
    required String editLabel,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    return PopupMenuButton<String>(
      tooltip: '메뉴',
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(editLabel, style: const TextStyle(fontSize: 13.5)),
            ],
          ),
        ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: AppColors.coral),
                SizedBox(width: 8),
                Text(
                  '삭제',
                  style: TextStyle(fontSize: 13.5, color: AppColors.coral),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 34, color: AppColors.coral),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              '다시 시도',
              style: TextStyle(
                color: AppColors.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String hint,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 부서 시트

/// 부서 추가/이름 변경 바텀시트.
///
/// onSubmit 이 null 을 반환하면 성공으로 보고 true 를 pop 하고,
/// 메시지를 반환하면 시트를 닫지 않고 입력창 아래에 그대로 보여준다(이름 중복 등).
class _DepartmentFormSheet extends StatefulWidget {
  final Department? department;
  final Future<String?> Function(String name) onSubmit;

  const _DepartmentFormSheet({this.department, required this.onSubmit});

  @override
  State<_DepartmentFormSheet> createState() => _DepartmentFormSheetState();
}

class _DepartmentFormSheetState extends State<_DepartmentFormSheet> {
  late final TextEditingController _controller;
  String? _error;
  bool _isSaving = false;

  bool get _isEdit => widget.department != null;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.department?.departmentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '부서명을 입력해 주세요.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final error = await widget.onSubmit(name);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSaving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 키보드가 올라오면 시트도 함께 밀어 올린다.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(title: _isEdit ? '부서 이름 변경' : '부서 추가'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 50,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: '부서명',
                errorText: _error,
                errorMaxLines: 2,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            _SheetSubmitButton(
              label: _isEdit ? '저장' : '등록',
              isSaving: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 팀 시트

/// 팀 시트의 확정 값. managerId 는 담당자를 바꿀 때만 채워진다.
class _TeamFormData {
  final String teamName;
  final int? departmentId;
  final int? parentTeamId;
  final int? managerId;

  _TeamFormData({
    required this.teamName,
    this.departmentId,
    this.parentTeamId,
    this.managerId,
  });
}

/// 팀 추가/수정 바텀시트.
///
/// - 소속 부서는 필수. 수정 시 부서를 바꾸면 소속 사원의 부서도 함께 바뀐다(서버 동작).
/// - 상위 팀은 등록 시 미지정 가능(대표이사 팀 직속). 루트 팀 수정 시에는 노출하지 않는다.
/// - 담당자는 등록 시 필수 1명. 수정 시 새로 고르면 기존 담당자 전원이 교체된다.
class _TeamFormSheet extends StatefulWidget {
  final Team? team;
  final List<Department> departments;
  final List<Team> teams;
  final Future<String?> Function(_TeamFormData data) onSubmit;

  const _TeamFormSheet({
    this.team,
    required this.departments,
    required this.teams,
    required this.onSubmit,
  });

  @override
  State<_TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends State<_TeamFormSheet> {
  /// '상위 팀 미지정(대표이사 팀 직속)'을 나타내는 드롭다운 값.
  static const int _kNoParent = -1;

  late final TextEditingController _nameController;

  int? _departmentId;
  int? _parentTeamId;
  Employee? _pickedManager;

  String? _nameError;
  String? _departmentError;
  String? _managerError;
  String? _serverError;
  bool _isSaving = false;

  bool get _isEdit => widget.team != null;

  bool get _isRootEdit => widget.team?.isRoot ?? false;

  /// 상위 팀 후보. 수정 시 자기 자신과 하위 팀 전체를 제외한다(서버 제약과 동일).
  List<Team> get _parentCandidates {
    final origin = widget.team;
    if (origin == null) return widget.teams;
    final excluded = _descendantIds(origin)..add(origin.teamId);
    return widget.teams.where((t) => !excluded.contains(t.teamId)).toList();
  }

  Set<int> _descendantIds(Team root) {
    final childrenOf = <int, List<Team>>{};
    for (final team in widget.teams) {
      final parentId = team.parentTeamId;
      if (parentId != null && parentId != team.teamId) {
        childrenOf.putIfAbsent(parentId, () => []).add(team);
      }
    }
    final result = <int>{};
    void visit(int id) {
      for (final child in childrenOf[id] ?? const <Team>[]) {
        if (result.add(child.teamId)) visit(child.teamId);
      }
    }

    visit(root.teamId);
    return result;
  }

  /// 수정 모드에서 무언가 하나라도 바뀌었는지. 저장 버튼 활성화에 쓴다.
  bool get _hasChanges {
    final origin = widget.team;
    if (origin == null) return true;
    return _nameController.text.trim() != origin.teamName ||
        _departmentId != origin.departmentId ||
        (!_isRootEdit &&
            _parentTeamId != _kNoParent &&
            _parentTeamId != origin.parentTeamId) ||
        _pickedManager != null;
  }

  @override
  void initState() {
    super.initState();
    final origin = widget.team;
    _nameController = TextEditingController(text: origin?.teamName ?? '');
    _nameController.addListener(() => setState(() {}));

    _departmentId = origin?.departmentId;
    if (_departmentId != null &&
        !widget.departments.any((d) => d.departmentId == _departmentId)) {
      _departmentId = null;
    }

    if (origin == null) {
      _parentTeamId = _kNoParent;
    } else if (!origin.isRoot) {
      _parentTeamId = _parentCandidates
              .any((t) => t.teamId == origin.parentTeamId)
          ? origin.parentTeamId
          : null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickManager() async {
    final picked = await showDialog<Employee>(
      context: context,
      builder: (_) => EmployeePickerDialog(
        title: '팀 담당자 선택',
        excludeEmployeeNumbers: [
          if (_pickedManager != null) _pickedManager!.employeeNumber,
        ],
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedManager = picked;
      _managerError = null;
    });
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();

    var hasError = false;
    if (name.isEmpty) {
      _nameError = '팀명을 입력해 주세요.';
      hasError = true;
    }
    if (_departmentId == null) {
      _departmentError = '소속 부서를 선택해 주세요.';
      hasError = true;
    }
    if (!_isEdit && _pickedManager == null) {
      _managerError = '팀 담당자를 지정해 주세요.';
      hasError = true;
    }
    if (_pickedManager != null && _pickedManager!.employeeId == null) {
      // 사원 목록 API 가 employeeId 를 내려주지 않으면 담당자를 지정할 수 없다.
      _managerError = '사원 정보에 employeeId가 없어 담당자로 지정할 수 없습니다.';
      hasError = true;
    }
    if (hasError) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
      _serverError = null;
    });
    final error = await widget.onSubmit(_TeamFormData(
      teamName: name,
      departmentId: _departmentId,
      parentTeamId:
          _parentTeamId == _kNoParent ? null : _parentTeamId,
      managerId: _pickedManager?.employeeId,
    ));
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSaving = false;
        _serverError = error;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(title: _isEdit ? '팀 수정' : '팀 추가'),
              if (_serverError != null) ...[
                const SizedBox(height: 4),
                _buildServerErrorBanner(),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: !_isEdit,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: '팀명',
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 4),
              _buildDepartmentField(),
              if (!_isRootEdit) ...[
                const SizedBox(height: 16),
                _buildParentTeamField(),
              ],
              const SizedBox(height: 16),
              _buildManagerField(),
              const SizedBox(height: 20),
              _SheetSubmitButton(
                label: _isEdit ? '저장' : '등록',
                isSaving: _isSaving,
                onPressed: _isEdit && !_hasChanges ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.coral.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child:
                Icon(Icons.error_outline, size: 15, color: AppColors.coral),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _serverError!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentField() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      value: _departmentId,
      decoration: InputDecoration(
        labelText: '소속 부서',
        errorText: _departmentError,
        helperText: _isEdit ? '부서 변경 시 소속 사원 전원의 부서도 함께 변경됩니다.' : null,
        helperMaxLines: 2,
        helperStyle:
            const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      items: widget.departments
          .map((dept) => DropdownMenuItem(
                value: dept.departmentId,
                child: Text(
                  dept.departmentName,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (value) => setState(() {
        _departmentId = value;
        _departmentError = null;
      }),
    );
  }

  Widget _buildParentTeamField() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      value: _parentTeamId,
      decoration: const InputDecoration(
        labelText: '상위 팀',
        helperText: '상위 팀은 연차 결재선을 결정합니다.',
        helperStyle: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      items: [
        if (!_isEdit)
          const DropdownMenuItem(
            value: _kNoParent,
            child: Text('미지정 — 대표이사 팀 직속', overflow: TextOverflow.ellipsis),
          ),
        ..._parentCandidates.map((team) => DropdownMenuItem(
              value: team.teamId,
              child: Text(team.teamName, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (value) => setState(() => _parentTeamId = value),
    );
  }

  Widget _buildManagerField() {
    final existing = widget.team?.managers ?? const <TeamManager>[];
    final String label;
    final String? subLabel;
    if (_pickedManager != null) {
      label = _pickedManager!.position.isEmpty
          ? _pickedManager!.name
          : '${_pickedManager!.name} ${_pickedManager!.position}';
      subLabel = _pickedManager!.employeeNumber;
    } else if (existing.isNotEmpty) {
      label = existing.map((m) => m.display).join(', ');
      subLabel = existing.map((m) => m.employeeNumber).join(', ');
    } else {
      label = '담당자 선택';
      subLabel = null;
    }

    final isPlaceholder = _pickedManager == null && existing.isEmpty;
    final showReplaceNotice =
        _isEdit && _pickedManager != null && existing.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '담당자',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(
              _isEdit ? '(1명)' : '(필수 1명)',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isSaving ? null : _pickManager,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _managerError != null ? AppColors.coral : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPlaceholder ? Icons.person_add_alt : Icons.person,
                  size: 19,
                  color:
                      isPlaceholder ? AppColors.textMuted : AppColors.slate,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isPlaceholder
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  isPlaceholder ? '선택' : '변경',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_managerError != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              _managerError!,
              style: const TextStyle(fontSize: 12, color: AppColors.coral),
            ),
          ),
        if (showReplaceNotice)
          const Padding(
            padding: EdgeInsets.only(top: 5, left: 4),
            child: Text(
              '저장 시 기존 담당자 전원이 선택한 1명으로 교체됩니다.',
              style: TextStyle(fontSize: 11.5, color: AppColors.amber),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 시트 공통 위젯

/// 바텀시트 상단의 드래그 핸들 + 제목 + 닫기 버튼.
class _SheetHeader extends StatelessWidget {
  final String title;

  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close,
                  size: 20, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

/// 바텀시트 하단의 전체 폭 저장 버튼. 저장 중에는 스피너를 보여준다.
class _SheetSubmitButton extends StatelessWidget {
  final String label;
  final bool isSaving;
  final VoidCallback? onPressed;

  const _SheetSubmitButton({
    required this.label,
    required this.isSaving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        child: isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}