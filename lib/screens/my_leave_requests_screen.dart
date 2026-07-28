import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';

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
      //widget.status = '';
    }
    
    _fetch(_statusFilter);
  }

  Future<void> _fetch(widgetStatus) async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }
      if(widgetStatus != null){
        _statusFilter = widget.status;
        queryParams['status'] = _statusFilter;
      }
      if (_dateRange != null) {
        queryParams['startDate'] = _formatDate(_dateRange!.start);
        queryParams['endDate'] = _formatDate(_dateRange!.end);
      }

      final response = await ApiClient().dio.get(
        '/api/leave-requests/my',
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

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
    _fetch(null);
  }

  bool _isCancelable(LeaveRequestListItem item) {
    
    if (item.status == 'PENDING') return true;

    return false;
    
    /*if (item.status != 'PENDING' && item.status != 'APPROVED') return false;

    final startDate = DateTime.parse(item.startDate);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // 휴가 시작일이 오늘이거나 이미 지났으면 취소 불가
    return startDate.isAfter(todayDateOnly); */
  }

  Future<void> _confirmCancel(LeaveRequestListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('신청 취소', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${item.startDate} — ${item.endDate} (${item.useDays}일)\n신청을 취소하시겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('취소하기', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancel(item.requestId);
    } 
  }

  Future<void> _cancel(int requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient().dio.delete('/api/leave-requests/$requestId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신청이 취소되었습니다.')));
      }
      await _fetch(null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취소 처리에 실패했습니다.')));
      }
    } finally {
      setState(() => _processingIds.remove(requestId));
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
      _fetch(null);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    //로그인 사용자 정보
    //final info = context.watch<AuthProvider>().employeeInfo;
    
    
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
          SizedBox(
            height: 60, 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    child: DropdownButton<String?>(
                      value: _statusFilter,
                      items: statusOptions.map((option) {
                        return DropdownMenuItem<String?>(
                          value: option['value'],
                          child: Text(option['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        _statusFilter = '';
                        _setFilter(value);
                      },
                      underline: Container(height: 1, color: Colors.grey),
                      isExpanded: true,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _pickDateRange();  
                    },
                    icon: const Icon(Icons.calendar_today, size: 20),
                    label: const Text(
                      '기간 선택',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(100, 36),
                    ),
                  ),
                ],
              ),
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
                      _fetch(null);
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

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRejected ? AppColors.coral.withOpacity(0.35) : AppColors.divider,
                    ),
                  ),
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
                                ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                            )
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