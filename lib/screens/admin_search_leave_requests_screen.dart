import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'package:annual_leave_frontend/main.dart';
import 'package:intl/intl.dart';

class AdminSearchLeaveRequestsScreen extends StatefulWidget {
  final String? status;
  final String? filter;

  const AdminSearchLeaveRequestsScreen({super.key, this.status, this.filter});

  @override
  State<AdminSearchLeaveRequestsScreen> createState() => _AdminSearchLeaveRequestsScreen();
}

class _AdminSearchLeaveRequestsScreen extends State<AdminSearchLeaveRequestsScreen> with RouteAware{
  List<LeaveRequestListItem> _requests = [];
  String? _errorMessage;
  bool _isLoading = true;
  String? _status; // null = 전체
  final Set<int> _processingIds = {};
  // 오늘 날짜 구하기
  final DateTime _today = DateTime.now();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.filter != null) {
      
      /*if (widget.filter != null) {
        _buttonLabel = widget.filter! == 'admin_approved' ? "내 신청" : "전체";
      }*/
      _setFilter(widget.filter);
    }

    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_status != null) {
        queryParams['status'] = _status;
      }

      //기본 당해년도 조회 날짜 세팅
      // 오늘 날짜가 속한 연도 구하기
      int year = _today.year;

      // 그 연도의 1월 1일 날짜 만들기
      DateTime firstDayOfYear = DateTime(year, 1, 1);
      DateTime lastDayOfYear = DateTime(year, 12, 31);

      queryParams['startDate'] = _formatDate(firstDayOfYear);
      queryParams['endDate'] = _formatDate(lastDayOfYear);

      final response = await ApiClient().dio.get(
            '/api/admin/leave-requests/${_status}',
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );
      final list = (response.data as List)
          .map((json) => LeaveRequestListItem.fromJson(json))
          .toList();
      setState(() => _requests = list);
    } catch (e) {
      setState(() => _errorMessage = '목록을 불러오지 못했습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setFilter(String? status) {
    _status = widget.filter! == 'admin_approved' ? "approved" : "rejected";

    _fetch();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }


  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'; //yyyy-mm-dd

  @override
  Widget build(BuildContext context) {
    final statusName = _status == 'approved' ? "승인": "반려";
    
    return Scaffold(
      appBar: AppBar(title: Text('$statusName 목록')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.slate))
                : _requests.isEmpty
                    ? const Center(
                        child: Text('조회된 내역이 없습니다.',
                            style: TextStyle(color: AppColors.textMuted)))
                    : Theme(
                        data: Theme.of(context).copyWith(
                          scrollbarTheme: ScrollbarThemeData(
                            thumbColor: WidgetStatePropertyAll(
                              Colors.black.withValues(alpha: 0.3),
                            ),
                            thickness: WidgetStatePropertyAll(5),
                            radius: const Radius.circular(8),
                          ),
                        ),
                        child: Scrollbar(
                          controller: _scrollController,
                          interactive: true,
                          child: ListView.builder(
                            controller: _scrollController, // 추가
                            padding: const EdgeInsets.all(20),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final item = _requests[index];
                              final isProcessing =
                                  _processingIds.contains(item.requestId);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            '${item.employeeName} ${item.position}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5)),
                                        // 2. 이름과 부서 사이의 좁은 가로 간격
                                        const SizedBox(width: 8),

                                        // 3. 부서명 (이제 직급 바로 옆에 붙습니다)
                                        Text(
                                          item.department,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          const SizedBox(height: 10),
                                          Text(
                                              '${item.startDate} — ${item.endDate}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 4),
                                          Text('(${item.useDays}일)',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppColors.textMuted)),
                                          const SizedBox(width: 70),

                                          // 1. 중간 빈 공간을 자동으로 가득 채워 우측 버튼을 끝으로 밀어냅니다.
                                          const Spacer(),
                                        ]),
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          const SizedBox(height: 10),
                                          Text(
                                              '신청일 : ${DateFormat('yyyy-MM-dd').format(DateTime.parse(item.requestedAt))}',
                                              style: const TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                        ])
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
