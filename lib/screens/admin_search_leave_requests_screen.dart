import 'package:annual_leave_frontend/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/screens/leave_request_detail_screen.dart';
import 'package:dio/src/response.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchEmployeeController = TextEditingController();
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
      if (_searchEmployeeController.text.isNotEmpty) {
        queryParams['employeeParam'] = _searchEmployeeController.text;
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

    //로그인 사용자 직급 "사장"여부 확인
    /* final auth = context.watch<AuthProvider>();
    final info = auth.employeeInfo;
    bool isCeo = false;
    if(auth.isAdmin && info?.position == "사장"){
      isCeo = true;
    } */
    
    //LeaveType leaveType = ;
    

    return Scaffold(
      appBar: AppBar(title: Text('$statusName 목록')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // 사장인 경우만 팀 콤보 표시
          //if (isCeo)
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 팀 선택 콤보박스
                    Flexible(
                      flex: 1,
                      child: Container(
                        height: 37,
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
                                (team) => DropdownMenuItem<String>(
                                  value: team,
                                  child: Text(team),
                                ),
                              )
                              .toList(),
                          // 선택 표시 영역
                          selectedItemBuilder: (context) {
                            return _teamList.map(
                              (team) => Container(
                                alignment: Alignment.centerLeft,
                                height: 35,
                                child: Text(
                                  team,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ).toList();
                          },
                          onChanged: _setTeamFilter,
                          underline: const SizedBox(),
                          isExpanded: true,
                          dropdownColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 검색 조건
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 4),
                        height: 35,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchEmployeeController,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                                onSubmitted: (_) => _fetch(),
                                decoration: const InputDecoration(
                                  hintText: '사번 또는 성명',
                                  hintStyle: TextStyle(
                                    fontSize: 14, // placeholder 크기 조정
                                    color: AppColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                    left: 6,
                                    right: 10,
                                    top: 10,
                                    bottom: 10,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 42,
                                height: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F3A5F), // 네이비
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.start,
              // 1. 메인 축 정렬을 우측 정렬로 설정합니다.
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 💡 실제 리스트 데이터인 _items의 길이를 가져와 동적으로 건수를 표시합니다. (조회건수)

                Text(
                  '${_items.length}건',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate, // 강조하고 싶은 테마 색상으로 지정 가능합니다.
                    fontWeight: FontWeight.w700, // 숫자를 두껍게 처리하여 가독성을 높입니다.
                  ),
                ),
              ],
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
                            padding: const EdgeInsets.fromLTRB(20,5,20,20),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final leaveTypeNm = LeaveType.getLabel(item.leaveType);
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LeaveRequestDetailScreen(
                                        requestId: item.requestId,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
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
                                          // 3. 부서명 
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
                                                '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600)),
                                            const SizedBox(width: 4),
                                            Text('(${item.useDays}일) [$leaveTypeNm]',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.textMuted)),
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
                                                '신청일 : ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.requestedAt))}',
                                                style: const TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600)),
                                          ])
                                    ],
                                  ),
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
