import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';
import '../widgets/date_range_dialog.dart';
import 'package:annual_leave_frontend/main.dart';
import 'package:intl/intl.dart';

import 'leave_request_detail_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

class AllLeaveRequestsScreen extends StatefulWidget {
  final String? status;
  final String? filter;

  const AllLeaveRequestsScreen({super.key, this.status, this.filter});

  @override
  State<AllLeaveRequestsScreen> createState() => _AllLeaveRequestsScreenState();
}

class _AllLeaveRequestsScreenState extends State<AllLeaveRequestsScreen>
    with RouteAware {
  List<LeaveRequestListItem> _items = [];
  bool _isLoading = true;
  String? _statusFilter; // null = 전체
  DateTimeRange? _dateRange;
  String _buttonLabel = '전체'; //로드시 기본 버튼 라벨
  final Set<int> _processingIds = {};
  // 오늘 날짜 구하기
  final DateTime _today = DateTime.now();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.status != null) {
      _statusFilter = widget.status;

      if (widget.filter != null) {
        _buttonLabel = widget.filter! == 'my' ? "내 신청" : "전체";
      }
      _setFilter(widget.status);
    }

    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }

      //기본 당해년도 조회 날짜 세팅
      // 오늘 날짜가 속한 연도 구하기
      int year = _today.year;

      // 그 연도의 1월 1일 날짜 만들기
      DateTime firstDayOfYear = DateTime(year, 1, 1);
      DateTime lastDayOfYear = DateTime(year, 12, 31);

      queryParams['startDate'] = _formatDate(firstDayOfYear);
      queryParams['endDate'] = _formatDate(lastDayOfYear);

      if (_dateRange != null) {
        queryParams['startDate'] = _formatDate(_dateRange!.start);
        queryParams['endDate'] = _formatDate(_dateRange!.end);
      }

      final response = await ApiClient().dio.get(
            _buttonLabel == "내 신청"
                ? '/api/leave-requests/my'
                : '/api/leave-requests/all',
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 다른 화면에서 돌아왔을 때
    _fetch();
  }

  bool _isCancelable(LeaveRequestListItem item, userEmployeeNumber) {
    if (item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber)
      return true;

    return false;
  }

  Future<void> _confirmCancel(LeaveRequestListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
        title:
            const Text('신청 취소', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))} (${item.useDays}일)\n신청을 취소하시겠습니까?',
          style: TextStyle(fontSize: 14.sp, height: 1.5.h),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('아니오', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('취소하기',
                style: TextStyle(
                    color: AppColors.coral, fontWeight: FontWeight.w700)),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('신청이 취소되었습니다.')));
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('취소 처리에 실패했습니다.')));
      }
    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'; //yyyy-mm-dd

  Future<void> _pickDateRange() async {
    final year = _today.year;
    final initial = _dateRange ?? DateTimeRange(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.slate,
              ),
        ),
        child: DateRangeDialog(
          initialRange: initial,
        ),
      ),
    );

    // 값이 실제로 바뀌었고, 화면이 아직 살아있을 때만 반영 및 재조회
    if (picked != null && picked != _dateRange && mounted) {
      setState(() {
        _dateRange = picked;
      });

      _fetch();
    }
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final userEmployeeNumber =
        context.watch<AuthProvider>().employeeInfo?.employeeNumber;
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
            height: 60.h,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.2.w,
                    height: 40.h, // 원하는 높이로 조절
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // 흰 바탕
                        border: Border.all(
                            color: Colors.grey.shade300), // 옅은 회색 테두리
                        borderRadius: BorderRadius.circular(8.r), // 모서리 약간 둥글게
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w), // 안쪽 여백
                      child: DropdownButton<String?>(
                        value: _statusFilter,
                        items: statusOptions.map((option) {
                          return DropdownMenuItem<String?>(
                            value: option['value'],
                            child: Text(
                              option['label']!, 
                              style: TextStyle(fontSize: 14.sp)),
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
                  //const Spacer(), // 드롭다운과 버튼 그룹 사이 넓은 공간 확보
                  SizedBox(width: 8.w), //간격
                  Row(
                    children: [
                      // UI 코드 예시: 라디오 버튼 목록 만들기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: searchFilterList.map((item) {
                          final label = item['label']!;
                          return Padding(
                            // '전체' 글자와 '내 신청' 아이콘이 붙지 않도록 오른쪽에만 여백을 줍니다.
                            padding: EdgeInsets.only(right: 10.w),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<String>(
                                  value: label,
                                  groupValue: _buttonLabel,
                                  // 1. 아이콘 주변의 불필요한 기본 시각적 여백을 완전히 제거합니다.
                                  visualDensity: const VisualDensity(
                                    horizontal: VisualDensity.minimumDensity,
                                    vertical: VisualDensity.minimumDensity,
                                  ),
                                  // 2. 터치 영역 제한(48x48)을 풀어 글자와 완전히 밀착시킵니다.
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (value) {
                                    setState(() {
                                      _buttonLabel = value!;
                                      _setFilter(_statusFilter);
                                    });
                                  },
                                ),
                                SizedBox(width: 2.w),
                                Text(label, style: TextStyle(fontSize: 14.sp)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(width: 8.w), // 두 버튼 간격
                      ElevatedButton.icon(
                        onPressed: () {
                          _pickDateRange();
                        },
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: Text(
                          '기간',
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 8.h),
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
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Text(
                      '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                      style: TextStyle(
                          fontSize: 12.sp, color: AppColors.textMuted)),
                  SizedBox(width: 6.w),
                  InkWell(
                    onTap: () {
                      setState(() => _dateRange = null);
                      _fetch();
                    },
                    child: Text('지우기',
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.coral,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
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
                              Colors.black.withOpacity(0.3),
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
                            //padding: const EdgeInsets.all(20),
                            padding: EdgeInsets.only(
                                top: 4.0.h,
                                left: 20.0.w,
                                right: 20.0.w,
                                bottom: 20.0.h),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isProcessing =
                                  _processingIds.contains(item.requestId);
                              // 1. 영문 구분 코드를 한글명으로 매핑하는 맵 객체 선언
                              final Map<String, String> leaveTypeMap = {
                                'FULL': '연차',
                                'AM_HALF': '반차(오전)',
                                'PM_HALF': '반차(오후)',
                                'ALTERNATIVE': '대체 휴가',
                                'PARENTAL': '출산 휴가',
                                'FAMILY': '가족 돌봄 휴가',
                                'OTHER': '기타',
                              };

                              // 2. 현재 아이템의 휴가 종류 값을 가져와 매핑 (데이터 필드명에 맞게 item.leaveType 등으로 수정 가능)
                              final String rawType = item.leaveType ?? 'FULL';
                              final String leaveTypeNm =
                                  leaveTypeMap[rawType] ?? rawType;

                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Material(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              LeaveRequestDetailScreen(requestId: item.requestId),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16.r),
                                    child: Container(
                                      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.w),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(color: AppColors.divider),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('${item.employeeName} ${item.position}',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w700, fontSize: 14.5.sp)),
                                              SizedBox(width: 8.w),
                                              Text(
                                                item.department,
                                                style: TextStyle(
                                                  color: AppColors.textMuted,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                              const Spacer(),
                                              LeaveStatusBadge(status: item.status),
                                            ],
                                          ),
                                          Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                SizedBox(height: 10.h),
                                                Text(
                                                    '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))}',
                                                    style: TextStyle(
                                                        fontSize: 13.sp, fontWeight: FontWeight.w600)),
                                                SizedBox(width: 4.w),
                                                Text('(${item.useDays}일) [$leaveTypeNm]',
                                                    style: TextStyle(
                                                        fontSize: 13.sp, color: AppColors.textMuted)),
                                                const Spacer(),
                                              ]),
                                          Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                SizedBox(height: 10.h),
                                                Text(
                                                    '신청일 : ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.requestedAt))}',
                                                    style: TextStyle(
                                                        color: AppColors.textMuted,
                                                        fontSize: 12.sp,
                                                        fontWeight: FontWeight.w600)),
                                                SizedBox(width: 12.w),
                                                const Spacer(),
                                                if (_isCancelable(item, userEmployeeNumber)) ...[
                                                  TextButton(
                                                    onPressed:
                                                    isProcessing ? null : () => _confirmCancel(item),
                                                    style: TextButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(
                                                          horizontal: 4.w, vertical: 6.h),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    child: isProcessing
                                                        ? SizedBox(
                                                      width: 14.w,
                                                      height: 14.h,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors.textMuted,
                                                      ),
                                                    )
                                                        : Text(
                                                      '신청 취소',
                                                      style: TextStyle(
                                                        fontSize: 12.5.sp,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textMuted,
                                                        decoration: TextDecoration.underline,
                                                        decorationColor: AppColors.textMuted,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ])
                                        ],
                                      ),
                                    ),
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
