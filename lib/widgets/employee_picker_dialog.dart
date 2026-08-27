import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../services/department_team_api.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';

/// 사원을 검색해서 한 명을 고르는 다이얼로그.
///
/// 선택하면 [Employee] 를, 그냥 닫으면 null 을 반환한다.
///
/// ```dart
/// final picked = await showDialog<Employee>(
///   context: context,
///   builder: (_) => EmployeePickerDialog(
///     excludeEmployeeNumbers: selected.map((m) => m.employeeNumber).toList(),
///   ),
/// );
/// ```
class EmployeePickerDialog extends StatefulWidget {
  /// 이미 선택된 사번은 결과에서 제외한다(중복 선택 방지).
  final List<String> excludeEmployeeNumbers;

  final String title;

  /// 사원 검색 함수. 지정하지 않으면 관리자 사원 목록 API 를 사용한다.
  final Future<List<Employee>> Function(String? keyword)? searchFn;

  const EmployeePickerDialog({
    super.key,
    this.excludeEmployeeNumbers = const [],
    this.title = '사원 선택',
    this.searchFn,
  });

  @override
  State<EmployeePickerDialog> createState() => _EmployeePickerDialogState();
}

class _EmployeePickerDialogState extends State<EmployeePickerDialog> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Employee> _items = [];
  bool _isLoading = false;
  String? _error;

  /// 요청 순번. 늦게 도착한 이전 응답이 최신 결과를 덮어쓰지 못하게 한다.
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 1. 사원 조회 (검색어가 없으면 전체)
  Future<void> _fetch() async {
    if (!mounted) return;
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final search =
          widget.searchFn ?? DepartmentTeamApi.instance.searchEmployees;
      final fetched = (await search(_searchController.text))
          .where((emp) =>
              !widget.excludeEmployeeNumbers.contains(emp.employeeNumber))
          .toList();

      // 더 최신 요청이 이미 나갔다면 이 응답은 버린다.
      if (!mounted || seq != _requestSeq) return;
      setState(() => _items = fetched);
    } catch (e) {
      debugPrint('사원 목록 조회 실패: $e');
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = [];
        _error = '사원 목록을 불러오지 못했습니다.';
      });
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        height: 380,
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            Expanded(child: _buildResultList()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기', style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }

  // 2. 검색 입력창 (사용자 사번 조회 화면과 동일한 형태)
  Widget _buildSearchField() {
    return SizedBox(
      height: 35,
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        onSubmitted: (_) => _fetch(),
        decoration: InputDecoration(
          labelText: '사번 or 성명',
          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 9.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          suffixIcon: InkWell(
            onTap: _fetch,
            child: Container(
              width: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1F3A5F),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.search, color: Colors.white, size: 16),
            ),
          ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: 35),
        ),
      ),
    );
  }

  // 3. 검색 결과 목록
  Widget _buildResultList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.slate),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.coral, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetch,
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

    if (_items.isEmpty) {
      return const Center(
        child: Text(
          '조회된 사원이 없습니다.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildEmployeeItem(_items[index]),
      ),
    );
  }

  Widget _buildEmployeeItem(Employee emp) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context, emp),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.position.isEmpty
                        ? emp.name
                        : '${emp.name} ${emp.position}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${emp.employeeNumber} · ${emp.team.isEmpty ? '팀 미지정' : emp.team}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
