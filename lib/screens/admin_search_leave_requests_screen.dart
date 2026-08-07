import 'package:annual_leave_frontend/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/screens/leave_request_detail_screen.dart';
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
        _teamList.addAll(List<String>.from(data['accessibleTeam']));
        
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
                    Expanded(
                      flex: 1, // 💡 앞서 매칭해 둔 가로 폭 비율(13) 반영
                      child: SizedBox(
                        height: 35, // 💡 등록 상태 박스와 동일한 세로 규격 제한 유지
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedTeam,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.grey),
                          alignment: Alignment.centerLeft,

                          // 💡 [핵심 추가] 아웃라인 테두리 왼쪽 위에 '팀' 라벨 텍스트를 강제 배치합니다.
                          decoration: InputDecoration(
                            labelText: '팀',
                            labelStyle: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            isDense: true,

                            // 🔥 [높이 정렬 고정] 상하 패딩을 '등록 상태' 박스와 똑같은 '9.5'로 일치시켜
                            // 화면에서 두 콤보박스의 가로선 높이가 자석처럼 완벽한 일직선을 이루게 만듭니다.
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9.5),

                            // 💡 테두리 곡률(Radius: 8) 및 색상 디자인 통일
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedTeam = newValue;
                              });
                              _fetch();
                            }
                          },
                          items: (_teamList.isEmpty)
                              ? [
                                  const DropdownMenuItem<String>(
                                    value: '전체',
                                    child: Text('전체'),
                                  )
                                ]
                              : _teamList.map((String team) {
                                  return DropdownMenuItem<String>(
                                    value: team,
                                    child: Text(team,
                                        overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),
                    // 검색 조건
                    Expanded(
                      child: SizedBox(
                        height: 35,
                        child: TextField(
                          controller: _searchEmployeeController,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black,
                          ),
                          onSubmitted: (_) => _fetch(),
                          decoration: InputDecoration(
                            labelText: '사번 or 성명',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            isDense: true,

                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9.5,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade400,
                              ),
                            ),

                            suffixIcon: InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1F3A5F),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
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
                                      //두번째 Row (가로스크롤 적용)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))}'
                                                ' ~ '
                                                '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '(${item.useDays}일) [$leaveTypeNm]',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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