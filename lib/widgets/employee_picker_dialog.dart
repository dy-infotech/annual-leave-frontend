import 'package:flutter/material.dart';

import '../data/mock_department_team_store.dart';
import '../models/employee.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// 사원을 검색해서 한 명을 고르는 다이얼로그.
///
/// 선택하면 [Employee] 를, 그냥 닫으면 null 을 반환한다.
/// 팀 관리자 지정처럼 여러 명이 필요한 경우 호출부에서 반복 호출해 누적한다.
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

  const EmployeePickerDialog({
    super.key,
    this.excludeEmployeeNumbers = const [],
    this.title = '사원 선택',
  });

  @override
  State<EmployeePickerDialog> createState() => _EmployeePickerDialogState();
}

class _EmployeePickerDialogState extends State<EmployeePickerDialog> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Employee> _items = [];
  bool _isLoading = false;

  /// 요청 순번. 늦게 도착한 이전 응답이 최신 결과를 덮어쓰지 못하게 한다.
  int _requestSeq = 0;

  /// 사원 API 호출이 실패해 임시 데이터로 대체됐는지.
  bool _isMock = false;

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
    setState(() => _isLoading = true);

    try {
      if (kUseMockDepartmentTeamData) {
        final mock = MockDepartmentTeamStore.instance
            .searchEmployees(_searchController.text)
            .where((emp) =>
                !widget.excludeEmployeeNumbers.contains(emp.employeeNumber))
            .toList();
        if (!mounted || seq != _requestSeq) return;
        setState(() {
          _items = mock;
          _isMock = true;
        });
        return;
      }

      final Map<String, dynamic> queryParams = {};
      if (_searchController.text.trim().isNotEmpty) {
        queryParams['searchParam'] = _searchController.text.trim();
      }

      final response = await ApiClient().dio.get(
            '/api/admin/employees/all',
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );

      final fetched = (response.data as List)
          .map((json) => Employee.fromJson(json))
          .where((emp) =>
              !widget.excludeEmployeeNumbers.contains(emp.employeeNumber))
          .toList();

      // 더 최신 요청이 이미 나갔다면 이 응답은 버린다.
      if (!mounted || seq != _requestSeq) return;
      setState(() => _items = fetched);
    } catch (e) {
      // 사원 API 를 못 쓰는 환경에서도 관리자 지정 흐름을 확인할 수 있도록 임시 데이터로 대체한다.
      debugPrint('사원 목록 조회 실패, 임시 데이터로 대체: $e');
      if (!mounted || seq != _requestSeq) return;
      final mock = MockDepartmentTeamStore.instance
          .searchEmployees(_searchController.text)
          .where((emp) =>
              !widget.excludeEmployeeNumbers.contains(emp.employeeNumber))
          .toList();
      setState(() {
        _items = mock;
        _isMock = true;
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
            if (_isMock)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '임시 데이터로 조회 중입니다.',
                  style: TextStyle(fontSize: 11, color: AppColors.amber),
                ),
              ),
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
