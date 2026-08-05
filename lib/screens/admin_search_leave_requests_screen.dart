import 'package:annual_leave_frontend/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/screens/leave_request_detail_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import 'package:annual_leave_frontend/main.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

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
              height: 50.h,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 팀 선택 콤보박스
                    Flexible(
                      flex: 1,
                      child: Container(
                        height: 37.h,
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedTeam,
                          items: _teamList
                              .map(
                                (team) => DropdownMenuItem<String>(
                                  value: team,
                                  child: Text(team, 
                                    style: TextStyle(fontSize: 14.sp)),
                                ),
                              )
                              .toList(),
                          // 선택 표시 영역
                          selectedItemBuilder: (context) {
                            return _teamList.map(
                              (team) => Container(
                                alignment: Alignment.centerLeft,
                                height: 35.h,
                                child: Text(
                                  team,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14.sp)
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
                    SizedBox(width: 10.w),
                    // 검색 조건
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.only(left: 4.w),
                        height: 35.h,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchEmployeeController,
                                textInputAction: TextInputAction.search,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                ),
                                onSubmitted: (_) => _fetch(),
                                decoration: InputDecoration(
                                  hintText: '사번 또는 성명',
                                  hintStyle: TextStyle(
                                    fontSize: 14.sp, // placeholder 크기 조정
                                    color: AppColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.only(
                                    left: 6.w,
                                    right: 10.w,
                                    top: 10.h,
                                    bottom: 10.h,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            Container(
                              width: 1.w,
                              color: Colors.grey.shade300,
                            ),
                            InkWell(
                              onTap: _fetch,
                              child: Container(
                                width: 42.w,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Color(0xFF1F3A5F), // 네이비
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8.r),
                                    bottomRight: Radius.circular(8.r),
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
                EdgeInsets.symmetric(horizontal: 24.0.w, vertical: 8.0.h),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.start,
              // 1. 메인 축 정렬을 우측 정렬로 설정합니다.
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 💡 실제 리스트 데이터인 _items의 길이를 가져와 동적으로 건수를 표시합니다. (조회건수)

                Text(
                  '${_items.length}건',
                  style: TextStyle(
                    fontSize: 13.sp,
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
                            padding: EdgeInsets.fromLTRB(20.w, 5.h, 20.w, 20.h),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final leaveTypeNm = LeaveType.getLabel(item.leaveType);
                              return InkWell(
                                borderRadius: BorderRadius.circular(16.r),
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
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  padding:
                                      EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16.r),
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
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5.sp)),
                                          // 2. 이름과 부서 사이의 좁은 가로 간격
                                          SizedBox(width: 8.w),
                                          // 3. 부서명 
                                          Text(
                                            item.department,
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            SizedBox(height: 10.h),
                                            Text(
                                                '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))}',
                                                style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w600)),
                                            SizedBox(width: 4.w),
                                            Text('(${item.useDays}일) [$leaveTypeNm]',
                                                style: TextStyle(
                                                    fontSize: 13.sp,
                                                    color: AppColors.textMuted)),
                                            // 1. 중간 빈 공간을 자동으로 가득 채워 우측 버튼을 끝으로 밀어냅니다.
                                            const Spacer(),
                                          ]),
                                      Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            SizedBox(height: 10.h),
                                            Text(
                                                '신청일 : ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.requestedAt))}',
                                                style: TextStyle(
                                                    color: AppColors.textMuted,
                                                    fontSize: 12.sp,
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
