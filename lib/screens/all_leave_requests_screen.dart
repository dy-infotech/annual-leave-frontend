import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';

class AllLeaveRequestsScreen extends StatefulWidget {
  const AllLeaveRequestsScreen({super.key});

  @override
  State<AllLeaveRequestsScreen> createState() => _AllLeaveRequestsScreenState();
}

class _AllLeaveRequestsScreenState extends State<AllLeaveRequestsScreen> {
  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }
      if (_dateRange != null) {
        queryParams['startDate'] = _formatDate(_dateRange!.start);
        queryParams['endDate'] = _formatDate(_dateRange!.end);
      }

      final response = await ApiClient().dio.get(
        '/api/leave-requests/all',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      setState(() {
        _items = (response.data as List)
            .map((json) => LeaveRequestListItem.fromJson(json))
            .toList();
      });

    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.slate),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetch();
    }
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('전체 신청 목록')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: '전체', selected: _statusFilter == null, onTap: () => _setFilter(null)),
                        _FilterChip(label: '대기', selected: _statusFilter == 'PENDING', onTap: () => _setFilter('PENDING')),
                        _FilterChip(label: '승인', selected: _statusFilter == 'APPROVED', onTap: () => _setFilter('APPROVED')),
                        _FilterChip(label: '반려', selected: _statusFilter == 'REJECTED', onTap: () => _setFilter('REJECTED')),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('기간', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ),
                ),
              ],
            ),
          ),
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() => _dateRange = null);
                      _fetch();
                    },
                    child: const Text('지우기', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.slate))
                : _items.isEmpty
                    ? const Center(child: Text('조회된 내역이 없습니다.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item.employeeName} ${item.position}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    LeaveStatusBadge(status: item.status),
                                  ],
                                ),
                                Text(item.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const SizedBox(height: 10),
                                Text('신청일 ${item.requestedAt.substring(0, 10)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text('${item.startDate} — ${item.endDate}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${item.useDays}일', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.slate : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.slate : AppColors.divider),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
