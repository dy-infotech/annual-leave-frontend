import 'package:flutter/material.dart';
import '../services/leave_request_service.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';
import '../widgets/leave_filter_bar.dart';
import '../widgets/loading.dart';
import '../widgets/surface_card.dart';

class AllLeaveRequestsScreen extends StatefulWidget {
  
  final String? status;
  
  const AllLeaveRequestsScreen({super.key, this.status});

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
    
    if(widget.status != null){
      _statusFilter = widget.status;
      _setFilter(widget.status);
    }

    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      if (widget.status != null) {
        _statusFilter = widget.status;
      }
      final items = await fetchLeaveRequestList(
        '/api/leave-requests/all',
        status: _statusFilter,
        dateRange: _dateRange,
      );
      setState(() => _items = items);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await pickLeaveDateRange(context, initialRange: _dateRange);
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
    final List<Map<String, String?>> statusOptions = [
      {'label': '전체', 'value': null},
      {'label': '대기', 'value': 'PENDING'},
      {'label': '승인', 'value': 'APPROVED'},
      {'label': '반려', 'value': 'REJECTED'}
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('전체 신청 목록')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          LeaveFilterBar(
            statusOptions: statusOptions,
            selectedStatus: _statusFilter,
            onStatusChanged: _setFilter,
            dateRange: _dateRange,
            onPickDateRange: _pickDateRange,
            onClearDateRange: () {
              setState(() => _dateRange = null);
              _fetch();
            },
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingIndicator()
                : _items.isEmpty
                    ? const Center(child: Text('조회된 내역이 없습니다.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return SurfaceCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item.employeeName} ${item.position}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    Text(item.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    LeaveStatusBadge(status: item.status),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,   
                                  textBaseline: TextBaseline.alphabetic,   
                                  children: [
                                    const SizedBox(height: 10),
                                    //Text('신청일 ${item.requestedAt.substring(0, 10)}',
                                    //    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    Text('${item.startDate} — ${item.endDate}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),  // 여기 간격 넓힘!
                                    Text('(${item.useDays}일)', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                  ]
                                )
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
