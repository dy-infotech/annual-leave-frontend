import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/department_team_models.dart';
import '../models/employee.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/employee_picker_dialog.dart';

// 부서 및 팀 관리 화면.
//
// 한 화면 안에서 '부서' / '팀' 두 탭으로 나누어 각각 조회·추가·수정을 제공한다.
// 팀은 관리자를 최소 1명 지정해야 저장할 수 있다(백엔드 team.project_manager_id NOT NULL).
//
// 주의: 부서/팀 CRUD API 는 백엔드에 아직 없다(2026-08 기준).
// 목록 조회는 /api/admin/auth/common 으로 폴백하여 화면이 뜨도록 했고,
// 폴백 상태에서는 id 를 알 수 없으므로 추가·수정 진입을 모두 막는다.
// 아래 추정 경로와 확인 사항은 docs/api-spec-department-team.md 참고.
//   GET/POST /api/admin/departments, PUT /api/admin/departments/{departmentId}
//   GET/POST /api/admin/teams,       PUT /api/admin/teams/{teamId}

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

  /// 목록 조회가 폴백(이름만 조회)으로 떨어졌는지.
  /// 이 경우 id 가 없어 수정할 수 없고, 추가 API 도 없으므로 추가도 막는다.
  bool _deptFallback = false;
  bool _teamFallback = false;

  /// 부서/팀 폴백이 같은 /api/admin/auth/common 을 각각 호출하지 않도록 공유한다.
  Future<Map<String, dynamic>>? _commonFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  void _refreshAll() {
    _commonFuture = null; // 새로고침 때는 공통 코드도 다시 받는다
    _fetchDepartments();
    _fetchTeams();
  }

  /// 부서/팀 폴백이 공유하는 공통 코드 조회. 한 번만 호출된다.
  Future<Map<String, dynamic>> _fetchCommon() {
    return _commonFuture ??= ApiClient()
        .dio
        .get('/api/admin/auth/common')
        .then((res) => res.data as Map<String, dynamic>);
  }

  // 1. 부서 목록 조회
  Future<void> _fetchDepartments() async {
    if (!mounted) return;
    setState(() {
      _isDeptLoading = true;
      _deptError = null;
    });

    try {
      final response = await ApiClient().dio.get('/api/admin/departments');
      final fetched = (response.data as List)
          .map((json) => Department.fromJson(json as Map<String, dynamic>))
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

  /// 부서 CRUD API 가 없을 때의 폴백. 이름만 얻을 수 있어 추가·수정은 불가능하다.
  Future<void> _fetchDepartmentsFromCommon() async {
    try {
      final data = await _fetchCommon();
      final names = List<String>.from(data['department'] ?? const []);

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
        _deptFallback = false; // 안내 문구와 에러 문구가 겹치지 않도록 되돌린다
        _deptError = _messageOf(e, '부서 목록 조회에 실패했습니다.');
      });
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
      final response = await ApiClient().dio.get('/api/admin/teams');
      final fetched = (response.data as List)
          .map((json) => Team.fromJson(json as Map<String, dynamic>))
          .toList();

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
      final data = await _fetchCommon();
      // 배포된 서버는 accessibleTeam, 로컬 백엔드는 team 으로 내려준다.
      final names = List<String>.from(
          data['accessibleTeam'] ?? data['team'] ?? const []);

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
        _teamFallback = false;
        _teamError = _messageOf(e, '팀 목록 조회에 실패했습니다.');
      });
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

  // ---------------------------------------------------------------- 저장

  /// 201 Created 등 2xx 전체를 성공으로 본다.
  bool _isSuccess(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  // 3. 부서 등록/수정
  Future<void> _saveDepartment(Department? origin, String name) async {
    final isEdit = origin != null;
    if (!mounted) return;
    setState(() => _isDeptLoading = true);

    try {
      final body = DepartmentSaveRequest(departmentName: name).toJson();
      final response = isEdit
          ? await ApiClient()
              .dio
              .put('/api/admin/departments/${origin.departmentId}', data: body)
          : await ApiClient().dio.post('/api/admin/departments', data: body);

      if (_isSuccess(response.statusCode)) {
        _showSnackBar(isEdit ? '부서가 수정되었습니다.' : '부서가 등록되었습니다.');
        await _fetchDepartments();
      } else {
        _showSnackBar(isEdit ? '부서 수정에 실패했습니다.' : '부서 등록에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('부서 저장 실패: $e');
      _showSnackBar(
          _messageOf(e, isEdit ? '부서 수정에 실패했습니다.' : '부서 등록에 실패했습니다.'));
    } finally {
      if (mounted) setState(() => _isDeptLoading = false);
    }
  }

  // 4. 팀 등록/수정
  Future<void> _saveTeam(Team? origin, _TeamFormResult form) async {
    final isEdit = origin != null;
    if (!mounted) return;
    setState(() => _isTeamLoading = true);

    try {
      final body = TeamSaveRequest(
        teamName: form.teamName,
        parentTeam: form.parentTeam,
        managerEmployeeNumbers:
            form.managers.map((m) => m.employeeNumber).toList(),
      ).toJson();

      final response = isEdit
          ? await ApiClient()
              .dio
              .put('/api/admin/teams/${origin.teamId}', data: body)
          : await ApiClient().dio.post('/api/admin/teams', data: body);

      if (_isSuccess(response.statusCode)) {
        _showSnackBar(isEdit ? '팀이 수정되었습니다.' : '팀이 등록되었습니다.');
        await _fetchTeams();
      } else {
        _showSnackBar(isEdit ? '팀 수정에 실패했습니다.' : '팀 등록에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('팀 저장 실패: $e');
      _showSnackBar(
          _messageOf(e, isEdit ? '팀 수정에 실패했습니다.' : '팀 등록에 실패했습니다.'));
    } finally {
      if (mounted) setState(() => _isTeamLoading = false);
    }
  }

  // ---------------------------------------------------------------- 다이얼로그

  // 5. 부서 추가/수정 (department 가 null 이면 추가 모드)
  Future<void> _openDepartmentDialog({Department? department}) async {
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DepartmentFormDialog(department: department),
    );
    if (name == null) return;
    await _saveDepartment(department, name);
  }

  // 6. 팀 추가/수정 (team 이 null 이면 추가 모드)
  Future<void> _openTeamDialog({Team? team}) async {
    // 상위 팀 후보: 기존 팀 이름(중복 제거).
    // 자기 자신도 제외하지 않는다 — 루트 팀은 자기 자신을 상위 팀으로 갖는다(시드 데이터 '대표이사').
    final parentCandidates =
        _teams.map((t) => t.teamName).where((n) => n.isNotEmpty).toSet();
    // 서버에 저장된 상위 팀이 목록에 없더라도 값이 유실되지 않도록 후보에 넣는다.
    final currentParent = team?.parentTeam;
    if (currentParent != null && currentParent.isNotEmpty) {
      parentCandidates.add(currentParent);
    }

    final result = await showDialog<_TeamFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TeamFormDialog(
        team: team,
        parentCandidates: parentCandidates.toList()..sort(),
      ),
    );
    if (result == null) return;
    await _saveTeam(team, result);
  }

  // ---------------------------------------------------------------- 화면

  @override
  Widget build(BuildContext context) {
    final isLoading = _isDeptLoading || _isTeamLoading;
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
    // 폴백 상태에서는 추가 API 도 없으므로 버튼을 막는다.
    final canAdd = !_isDeptLoading && !_deptFallback;
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '부서 추가',
          count: _departments.length,
          onAdd: canAdd ? () => _openDepartmentDialog() : null,
        ),
        if (_deptFallback) _buildFallbackNotice('부서'),
        _buildErrorSection(_deptError),
        Expanded(
          child: _buildListArea(
            isLoading: _isDeptLoading,
            hasError: _deptError != null,
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
    final canAdd = !_isTeamLoading && !_teamFallback;
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '팀 추가',
          count: _teams.length,
          onAdd: canAdd ? () => _openTeamDialog() : null,
        ),
        if (_teamFallback) _buildFallbackNotice('팀'),
        _buildErrorSection(_teamError),
        Expanded(
          child: _buildListArea(
            isLoading: _isTeamLoading,
            hasError: _teamError != null,
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

  /// 목록이 폴백 경로로 조회됐을 때의 안내. 이 상태에서는 추가·수정이 모두 불가능하다.
  Widget _buildFallbackNotice(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 14, color: AppColors.amber),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label 관리 API가 아직 준비되지 않아 이름만 조회했습니다. 추가·수정은 사용할 수 없습니다.',
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

  /// 로딩 / 에러 / 빈 목록 / 리스트 4분기를 담당하는 공통 영역.
  /// 에러 문구는 위쪽 _buildErrorSection 이 이미 보여주므로 여기서는 빈 자리만 둔다.
  Widget _buildListArea({
    required bool isLoading,
    required bool hasError,
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

    if (hasError) return const SizedBox.shrink();

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
    return _buildListCard(
      editable: editable,
      onTap: editable ? () => _openDepartmentDialog(department: dept) : null,
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
          if (editable)
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildTeamItem(Team team) {
    final editable = team.isEditable;
    final managerText = team.managers.isEmpty
        ? '관리자 미지정'
        : team.managers.map((m) => m.display).join(', ');

    return _buildListCard(
      editable: editable,
      onTap: editable ? () => _openTeamDialog(team: team) : null,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              if (editable)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted),
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
    );
  }

  /// 목록 카드 공통 껍데기. 수정할 수 없는 항목은 탭 반응 자체를 주지 않는다.
  Widget _buildListCard({
    required bool editable,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );

    if (!editable) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ------------------------------------------------------------------ 부서 다이얼로그

/// 부서 추가/수정 입력 다이얼로그.
///
/// 컨트롤러를 State 가 소유하게 해서, 다이얼로그 퇴장 애니메이션이 끝난 뒤
/// 프레임워크가 dispose 를 호출하도록 한다. 호출부에서 await 직후 dispose 하면
/// 아직 살아 있는 TextField 가 죽은 컨트롤러를 참조해 예외가 난다.
///
/// 확정 시 입력된 부서명을, 취소 시 null 을 반환한다.
class _DepartmentFormDialog extends StatefulWidget {
  final Department? department;

  const _DepartmentFormDialog({this.department});

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  late final TextEditingController _controller;
  String? _nameError;

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

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '부서명을 입력해 주세요.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        _isEdit ? '부서 수정' : '부서 추가',
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: '부서명',
            errorText: _nameError,
          ),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            _isEdit ? '수정' : '등록',
            style: const TextStyle(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 팀 다이얼로그

/// 팀 다이얼로그의 확정 결과.
class _TeamFormResult {
  final String teamName;
  final String parentTeam;
  final List<TeamManager> managers;

  _TeamFormResult({
    required this.teamName,
    required this.parentTeam,
    required this.managers,
  });
}

/// 팀 추가/수정 입력 다이얼로그.
///
/// 팀명·상위 팀·관리자를 입력받는다. 관리자는 사원 검색 다이얼로그로 고르며 최소 1명이 필수다.
/// 상위 팀도 백엔드 parent_team 이 NOT NULL 이므로 필수로 받는다.
class _TeamFormDialog extends StatefulWidget {
  final Team? team;
  final List<String> parentCandidates;

  const _TeamFormDialog({this.team, required this.parentCandidates});

  @override
  State<_TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<_TeamFormDialog> {
  late final TextEditingController _controller;
  late final List<TeamManager> _managers;

  String? _selectedParent;
  String? _nameError;
  String? _parentError;
  String? _managerError;

  bool get _isEdit => widget.team != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.team?.teamName ?? '');
    _managers = List<TeamManager>.from(widget.team?.managers ?? const []);

    // 기존 상위 팀은 호출부에서 후보에 포함시켜 두므로 그대로 살린다.
    final current = widget.team?.parentTeam;
    _selectedParent =
        (current != null && widget.parentCandidates.contains(current))
            ? current
            : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addManager() async {
    final picked = await showDialog<Employee>(
      context: context,
      builder: (_) => EmployeePickerDialog(
        title: '팀 관리자 선택',
        excludeEmployeeNumbers:
            _managers.map((m) => m.employeeNumber).toList(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _managers.add(TeamManager(
        employeeNumber: picked.employeeNumber,
        name: picked.name,
        position: picked.position,
      ));
      _managerError = null;
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '팀명을 입력해 주세요.');
      return;
    }
    // 백엔드 team.parent_team 이 NOT NULL 이므로 상위 팀도 필수다.
    if (_selectedParent == null) {
      setState(() => _parentError = '상위 팀을 선택해 주세요.');
      return;
    }
    // 팀 관리자는 최소 1명 필수 (백엔드 project_manager_id NOT NULL)
    if (_managers.isEmpty) {
      setState(() => _managerError = '팀 관리자를 최소 1명 지정해 주세요.');
      return;
    }
    Navigator.pop(
      context,
      _TeamFormResult(
        teamName: name,
        parentTeam: _selectedParent!,
        managers: _managers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        _isEdit ? '팀 수정' : '팀 추가',
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
                controller: _controller,
                autofocus: !_isEdit,
                decoration: InputDecoration(
                  labelText: '팀명',
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedParent,
                decoration: InputDecoration(
                  labelText: '상위 팀',
                  errorText: _parentError,
                ),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: widget.parentCandidates
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedParent = value;
                  _parentError = null;
                }),
              ),
              const SizedBox(height: 16),
              _buildManagerSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            _isEdit ? '수정' : '등록',
            style: const TextStyle(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagerSection() {
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
              onPressed: _addManager,
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
        if (_managerError != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              _managerError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        const SizedBox(height: 6),
        if (_managers.isEmpty)
          const Text(
            '지정된 관리자가 없습니다.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                _managers.map((m) => _buildManagerChip(m)).toList(),
          ),
      ],
    );
  }

  Widget _buildManagerChip(TeamManager manager) {
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
            onTap: () => setState(() => _managers.remove(manager)),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}
