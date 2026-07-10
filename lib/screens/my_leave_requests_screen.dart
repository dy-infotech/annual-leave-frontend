import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/leave_request_service.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../utils/ui_helpers.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';
import '../widgets/leave_filter_bar.dart';
import '../widgets/loading.dart';
import '../widgets/surface_card.dart';

class MyLeaveRequestsScreen extends StatefulWidget {

  final String? status;
  
  const MyLeaveRequestsScreen({super.key, this.status});

  @override
  State<MyLeaveRequestsScreen> createState() => _MyLeaveRequestsScreenState();
}

class _MyLeaveRequestsScreenState extends State<MyLeaveRequestsScreen> {

  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;
  final Set<int> _processingIds = {};   
  
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
        '/api/leave-requests/my',
        status: _statusFilter,
        dateRange: _dateRange,
      );
      setState(() => _items = items);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
    _fetch();
  }

  bool _isCancelable(LeaveRequestListItem item) {
    if (item.status != 'PENDING' && item.status != 'APPROVED') return false;

    final startDate = DateTime.parse(item.startDate);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // 휴가 시작일이 오늘이거나 이미 지났으면 취소 불가
    return startDate.isAfter(todayDateOnly);
  }

  Future<void> _confirmCancel(LeaveRequestListItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '신청 취소',
      content: Text(
        '${item.startDate} — ${item.endDate} (${item.useDays}일)\n신청을 취소하시겠습니까?',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      cancelLabel: '아니오',
      confirmLabel: '취소하기',
      confirmColor: AppColors.coral,
    );

    if (confirmed) {
      await _cancel(item.requestId);
    }
  }

  Future<void> _cancel(int requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient().dio.delete('/api/leave-requests/$requestId');
      if (mounted) {
        showSnackBarMessage(context, '신청이 취소되었습니다.');
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        showSnackBarMessage(context, '취소 처리에 실패했습니다.');
      }
    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await pickLeaveDateRange(context, initialRange: _dateRange);
    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetch();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final List<Map<String, String?>> statusOptions = [
      {'label': '전체', 'value': null},
      {'label': '대기', 'value': 'PENDING'},
      {'label': '승인', 'value': 'APPROVED'},
      {'label': '반려', 'value': 'REJECTED'},
      {'label': '취소', 'value': 'CANCELLED'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('내 신청 목록')),
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
                ? const Center(child: Text('신청 내역이 없습니다.', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isRejected = item.status == 'REJECTED' &&
                    item.rejectReason != null &&
                    item.rejectReason!.isNotEmpty;
                final isProcessing = _processingIds.contains(item.requestId);

                return SurfaceCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  borderColor: isRejected ? AppColors.coral.withOpacity(0.35) : AppColors.divider,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.startDate} — ${item.endDate}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('${item.useDays}일',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                          LeaveStatusBadge(status: item.status),
                        ],
                      ),
                      if (isRejected) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.coral.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,   
                            textBaseline: TextBaseline.alphabetic,             
                            children: [
                              const Text('반려 사유',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.coral)),
                              const SizedBox(width: 12),
                              Text(item.rejectReason!,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],

                      // 취소 버튼: 대기/승인 + 아직 시작 안 한 휴가만 표시
                      if (_isCancelable(item)) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.divider),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isProcessing ? null : () => _confirmCancel(item),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: isProcessing
                                ? const ButtonSpinner(size: 14, color: AppColors.textMuted)
                                : const Text(
                              '신청 취소',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
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