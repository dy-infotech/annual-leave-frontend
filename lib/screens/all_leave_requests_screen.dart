import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';

class AllLeaveRequestsScreen extends StatefulWidget {
  
  final String? status;
  final String? filter;
  
  const AllLeaveRequestsScreen({super.key, this.status, this.filter});

  @override
  State<AllLeaveRequestsScreen> createState() => _AllLeaveRequestsScreenState();
}

class _AllLeaveRequestsScreenState extends State<AllLeaveRequestsScreen> {
  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;
  String _buttonLabel = '전체';  //로드시 기본 버튼 라벨
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    
    if(widget.status != null){
      _statusFilter = widget.status;

      if(widget.filter != null){
        _buttonLabel = widget.filter! == 'my' ? "내 신청": "전체";
      }
      _setFilter(widget.status);
    }
    
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      /* if(widget.status != null && _statusFilter == null){
        _statusFilter = widget.status;
        queryParams['status'] = _statusFilter;
        widget.status = '';
      } */
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }
      
      if (_dateRange != null) {
        queryParams['startDate'] = _formatDate(_dateRange!.start);
        queryParams['endDate'] = _formatDate(_dateRange!.end);
      }

      final response = await ApiClient().dio.get(
        _buttonLabel == "내 신청" ? '/api/leave-requests/my' : '/api/leave-requests/all',
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

  bool _isCancelable(LeaveRequestListItem item, userEmployeeNumber) {
    
    if (item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber) return true;

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
      await _fetch();
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
      _fetch();
    }
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final userEmployeeNumber = context.watch<AuthProvider>().employeeInfo?.employeeNumber;
    //final userEmployeeNumber = AuthProvider().employeeInfo?.employeeNumber;
    final List<Map<String, String?>> statusOptions = [
      {'label': '전체', 'value': null},
      {'label': '대기', 'value': 'PENDING'},
      {'label': '승인', 'value': 'APPROVED'},
      {'label': '반려', 'value': 'REJECTED'},
      {'label': '취소', 'value': 'CANCELLED'}
    ];
    final List<Map<String, String?>> searchFilterList = [
      {'label': '전체', 'value': '전체'},
      {'label': '내 신청', 'value': '내 신청'},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('신청 목록')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          SizedBox(
            height: 60, 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start, 
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                    height: 40,  // 원하는 높이로 조절
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // 흰 바탕
                        border: Border.all(color: Colors.grey.shade300), // 옅은 회색 테두리
                        borderRadius: BorderRadius.circular(8), // 모서리 약간 둥글게
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8), // 안쪽 여백
                      child: DropdownButton<String?>(
                        value: _statusFilter,
                        items: statusOptions.map((option) {
                          return DropdownMenuItem<String?>(
                            value: option['value'],
                            child: Text(option['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _setFilter(value);
                        },
                        underline: SizedBox(), // 기본 밑줄 제거
                        isExpanded: true,
                        dropdownColor: Colors.white, // 드롭다운 목록도 흰색으로 맞춤
                      ),
                    ),
                  ),
                  const Spacer(),  // 드롭다운과 버튼 그룹 사이 넓은 공간 확보
                  Row(
                    children: [
                      // UI 코드 예시: 라디오 버튼 목록 만들기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: searchFilterList.map((item) {
                          final label = item['label']!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: label,
                                  // ignore: deprecated_member_use
                                  groupValue: _buttonLabel,
                                  // ignore: deprecated_member_use
                                  onChanged: (value) {
                                    setState(() {
                                      _buttonLabel = value!;
                                      _setFilter(_statusFilter);
                                    });
                                  },
                                ),
                                Text(label),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(width: 10), // 두 버튼 간격 
                      ElevatedButton.icon(
                        onPressed: () {
                          _pickDateRange();
                        },
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: const Text(
                          '기간',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(80, 36),
                        ),
                      ),
                    ],
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
                          final isProcessing = _processingIds.contains(item.requestId);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                                    Text(item.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    LeaveStatusBadge(status: item.status),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,   
                                  textBaseline: TextBaseline.alphabetic,   
                                  children: [
                                    const SizedBox(height: 10),
                                    Text('${item.startDate} — ${item.endDate}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),  
                                    Text('(${item.useDays}일)', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                    const SizedBox(width: 70), 
                                    // 취소 버튼: 대기/승인 + 아직 시작 안 한 휴가만 표시
                                    if (_isCancelable(item, userEmployeeNumber)) ...[
                                      const SizedBox(height: 20),
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
                                  ]
                                )
                              ],
                            ),
                          );
                        },
                    
          ),),
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
