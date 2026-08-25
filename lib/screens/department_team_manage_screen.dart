import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../data/mock_department_team_store.dart';
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
// 그래서 kUseMockDepartmentTeamData(= true)일 때는 HTTP 를 호출하지 않고
// 메모리 목업 저장소로 동작한다. 조회·추가·수정이 모두 실제로 동작하되
// 변경 사항은 앱을 다시 시작하면 사라진다.
//
// 백엔드가 아래 엔드포인트를 제공하면 그 상수만 false 로 바꾸면 된다.
// (요청/응답 형식과 확인 사항은 docs/api-spec-department-team.md 참고)
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

  /// 목록을 목업 저장소에서 읽었는지(= 백엔드 API 호출 실패).
  /// 이 모드에서도 조회·추가·수정이 모두 동작하되, 변경은 메모리에만 남는다.
  bool _deptMock = false;
  bool _teamMock = false;

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
    _fetchDepartments();
    _fetchTeams();
  }

  // 1. 부서 목록 조회
  Future<void> _fetchDepartments() async {
    if (!mounted) return;
    setState(() {
      _isDeptLoading = true;
      _deptError = null;
    });

    try {
      if (kUseMockDepartmentTeamData) {
        if (!mounted) return;
        setState(() {
          _departments = MockDepartmentTeamStore.instance.fetchDepartments();
          _deptMock = true;
        });
        return;
      }

      final response = await ApiClient().dio.get('/api/admin/departments');
      final fetched = (response.data as List)
          .map((json) => Department.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _departments = fetched;
        _deptMock = false;
      });
    } catch (e) {
      // 백엔드에 부서 CRUD API 가 아직 없다. 화면 확인이 가능하도록 목업으로 대체한다.
      debugPrint('부서 목록 조회 실패, 임시 데이터로 대체: $e');
      if (!mounted) return;
      setState(() {
        _departments = MockDepartmentTeamStore.instance.fetchDepartments();
        _deptMock = true;
      });
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
      if (kUseMockDepartmentTeamData) {
        if (!mounted) return;
        setState(() {
          _teams = MockDepartmentTeamStore.instance.fetchTeams();
          _teamMock = true;
        });
        return;
      }

      final response = await ApiClient().dio.get('/api/admin/teams');
      final fetched = (response.data as List)
          .map((json) => Team.fromJson(json as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _teams = fetched;
        _teamMock = false;
      });
    } catch (e) {
      // 백엔드에 팀 CRUD API 가 아직 없다. 화면 확인이 가능하도록 목업으로 대체한다.
      debugPrint('팀 목록 조회 실패, 임시 데이터로 대체: $e');
      if (!mounted) return;
      setState(() {
        _teams = MockDepartmentTeamStore.instance.fetchTeams();
        _teamMock = true;
      });
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
      // 임시 데이터 모드에서는 메모리 저장소에 반영한다.
      if (_deptMock) {
        MockDepartmentTeamStore.instance.saveDepartment(
          departmentId: origin?.departmentId,
          departmentName: name,
        );
        _showSnackBar(isEdit ? '부서가 수정되었습니다. (임시 데이터)' : '부서가 등록되었습니다. (임시 데이터)');
        await _fetchDepartments();
        return;
      }

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
    } on StateError catch (e) {
      // 목업 저장소의 제약 위반(이름 중복 등)
      _showSnackBar(e.message);
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
      // 임시 데이터 모드에서는 메모리 저장소에 반영한다.
      if (_teamMock) {
        MockDepartmentTeamStore.instance.saveTeam(
          teamId: origin?.teamId,
          teamName: form.teamName,
          parentTeam: form.parentTeam,
          managers: form.managers,
        );
        _showSnackBar(isEdit ? '팀이 수정되었습니다. (임시 데이터)' : '팀이 등록되었습니다. (임시 데이터)');
        await _fetchTeams();
        return;
      }

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
    } on StateError catch (e) {
      // 목업 저장소의 제약 위반(이름 중복, 관리자 미지정 등)
      _showSnackBar(e.message);
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
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '부서 추가',
          count: _departments.length,
          onAdd: _isDeptLoading ? null : () => _openDepartmentDialog(),
        ),
        if (_deptMock) _buildMockNotice(),
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
    return Column(
      children: [
        _buildTabHeader(
          addLabel: '팀 추가',
          count: _teams.length,
          onAdd: _isTeamLoading ? null : () => _openTeamDialog(),
        ),
        if (_teamMock) _buildMockNotice(),
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

  /// 목업 데이터로 동작 중임을 알리는 배너.
  /// 조회·추가·수정은 모두 동작하지만 변경 사항은 메모리에만 남는다.
  Widget _buildMockNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.science_outlined, size: 14, color: AppColors.amber),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '임시 데이터로 동작 중입니다. 백엔드 API가 아직 없어 변경 사항은 앱을 다시 시작하면 사라집니다.',
              style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
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
