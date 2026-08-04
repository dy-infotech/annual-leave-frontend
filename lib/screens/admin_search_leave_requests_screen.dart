import 'package:dio/src/response.dart';
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
  List<LeaveRequestListItem> _items = [];
  String? _errorMessage;
  bool _isLoading = true;
  String? _status;          // 진행 상태 (null = 전체)
  String? _selectedTeam = '전체';    // 선택된 팀 (null = 전체)
  // 오늘 날짜 구하기
  final DateTime _today = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  final List<String> _teamList = [];       //팀 

  @override
  void initState() {
    super.initState();

    if (widget.filter != null) {
      _setFilter(widget.filter);
    }

    _getComData();
      
    _fetch();
  }

  Future<void> _getComData() async{
    //기초데이터 조회: 팀목록
    final comResponse = await ApiClient().dio.get(
      '/api/admin/auth/common',
    );
    setState(() {
      final data = comResponse.data as Map<String, dynamic>;

      if (data.length >= 3) {
        _teamList.clear();
        _teamList.add('전체');  //전체 item 추가
        _teamList.addAll(List<String>.from(data['team']));
        
      } else {
        // 데이터가 이상할 때 대비한 예외처리
        setState(() => _errorMessage = '기초데이터 조회에 실패했습니다.');
        return;
      }
    });
  }


  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      
      //상태값 조회 파라미터 세팅     
      final queryParams = <String, dynamic>{};
      if (_status != null) {
        queryParams['status'] = _status;
      }
      if (_selectedTeam != null) {
        queryParams['team'] = _selectedTeam == '전체' ? null: _selectedTeam;
      }

      final response = await ApiClient().dio.get(
            '/api/admin/leave-requests/${_status}',
            queryParameters: queryParams.isEmpty ? null : queryParams,
            //'/api/admin/leave-requests/approved',
            //queryParameters: null
          );
      setState(() {
        _items = (response.data as List)
            .map((json) => LeaveRequestListItem.fromJson(json))
            .toList();
      });
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

  void _setTeamFilter(String? value) {
    _selectedTeam = value;

    _fetch();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusName = _status == 'approved' ? "승인": "반려";
    
    return Scaffold(
      appBar: AppBar(title: Text('$statusName 목록')),
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
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedTeam,
                        items: _teamList
                            .map(
                              (team) => DropdownMenuItem(
                                value: team,
                                child: Text(team),
                              ),
                            )
                            .toList(),
                        onChanged: _setTeamFilter,
                        underline: const SizedBox(),
                        isExpanded: true,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, 5),
                    child: Text(
                      '${_items.length}건 조회됨',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.slate))
                : _items.isEmpty
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
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
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

extension on Future<Response<dynamic>> {
  get data => null;
}
