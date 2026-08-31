import 'package:annual_leave_frontend/models/enums/LeaveType.dart';
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
  String _buttonLabel = '전체'; //로드 시 기본 버튼 라벨
  final Set<int> _processingIds = {};
  // 오늘 날짜 구하기
  final DateTime _today = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchParamController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.status != null) {
      _statusFilter = widget.status;

      if (widget.filter != null) {
        _buttonLabel = widget.filter! == 'my' ? "본인" : "전체";
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

      // 기본 당해년도 조회 날짜 세팅
      // 오늘 날짜가 속한 연도 구하기
      int year = _today.year;

      // 그 연도의 1월 1일 날짜 만들기
      DateTime firstDayOfYear = DateTime(year, 1, 1);
      DateTime lastDayOfYear = DateTime(year, 12, 31);

      queryParams['startDate'] = _formatDate(firstDayOfYear);
      queryParams['endDate'] = _formatDate(lastDayOfYear);

      // 사용자가 입력한 검색창 텍스트를 'searchEmployeeParam'이라는 이름으로 백엔드에 전송합니다.
      if (_searchParamController.text.trim().isNotEmpty) {
        queryParams['searchEmployeeParam'] = _searchParamController.text.trim();
      }

      // TO-BE (변경 후)
      final response = await ApiClient().dio.get(
            _buttonLabel == "본인"
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
    if (item.status == 'PENDING' && item.employeeNumber == userEmployeeNumber) {
      return true;
    }

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
        title:
            const Text('신청 취소', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.endDate))} (${item.useDays}일)\n신청을 취소하시겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.5),
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
    final initial = _dateRange ??
        DateTimeRange(
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

    final List<Map<String, String?>> statusOptions = [
      {'label': '전체', 'value': null},
      {'label': '대기', 'value': 'PENDING'},
      {'label': '승인', 'value': 'APPROVED'},
      {'label': '반려', 'value': 'REJECTED'},
      {'label': '취소', 'value': 'CANCELLED'}
    ];

    final List<Map<String, String>> scopeOptions = [
      {'value': '전체', 'label': '전체'},
      {'value': '본인', 'label': '본인'},
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
                  // 1. 상태 드롭다운 박스
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.23,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _statusFilter,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.grey),
                        alignment: Alignment.centerLeft,
                        decoration: InputDecoration(
                          labelText: '상태',
                          labelStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 9.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                        onChanged: (String? newValue) {
                          _setFilter(newValue);
                        },
                        items: statusOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option['value'],
                            child: Text(
                              option['label']!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  // 2. 전체/본인 드롭다운 박스
                  // 2. 전체/본인 드롭다운 박스 수정본
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.23,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _buttonLabel, // '전체' 또는 '본인'
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.grey),
                        alignment: Alignment.centerLeft,
                        decoration: InputDecoration(
                          labelText: '조회 대상',
                          labelStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 9.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                        ),
                        // 💡 정정된 onChanged 이벤트 처리
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _buttonLabel = newValue;
                            });
                            _fetch(); // 필터가 변경되었으므로 데이터를 다시 서버에서 가져옵니다.
                          }
                        },
                        // 💡 상태(Status) 옵션 대신 범위(Scope) 옵션으로 바르게 매핑
                        items: scopeOptions.map((option) {
                          return DropdownMenuItem<String>(
                            value: option['value'], // '전체' 또는 '본인'이 정상 공급됨
                            child: Text(
                              option['label']!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 5),

                  // 3. 사번/성명 검색 입력창
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchParamController,
                        textInputAction: TextInputAction.search,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        onSubmitted: (_) => _fetch(),
                        decoration: InputDecoration(
                          labelText: '사번 or 성명',
                          labelStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 9.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          suffixIcon: InkWell(
                            onTap: _fetch,
                            child: Container(
                              width: 30,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1F3A5F),
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: const Icon(Icons.search,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 💡 중요: 기존의 Spacer()와 라디오 버튼 Row를 통째로 지우고 미세한 간격만 남깁니다.
                  const SizedBox(width: 10),

                  // 2. 기간 선택 버튼 (가운데 정렬 교정본)
                  Container(
                    alignment: Alignment.center, // 세로축 가운데 정렬 보장
                    height: 40, // 주변 드롭다운/검색창 높이와 동일하게 지정
                    child: ElevatedButton(
                      onPressed: () {
                        _pickDateRange();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // 빈 문자열로 인한 치우침 방지
                        minimumSize: const Size(40, 40), // 정사각형 구조 유지
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8), // 주변 필드와 라운딩 일치
                        ),
                      ),
                      child: const Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ],
              ), // Row 끝
            ), // Padding 끝
          ), // SizedBox 끝

          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                      '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() => _dateRange = null);
                      _fetch();
                    },
                    child: const Text('지우기',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.coral,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.start,
              // 메인 축 정렬을 우측 정렬 설정
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 실제 리스트 데이터인 _items의 길이를 가져와 동적으로 건수를 표시 (조회건수)

                Text(
                  '${_items.length}건',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate,
                    fontWeight: FontWeight.w700,
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
                            padding: const EdgeInsets.only(
                                top: 4.0,
                                left: 20.0,
                                right: 20.0,
                                bottom: 20.0),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isProcessing =
                                  _processingIds.contains(item.requestId);
                              final leaveTypeNm =
                                  LeaveType.getLabel(item.leaveType);
                              // 1. 영문 구분 코드를 한글명으로 매핑하는 맵 객체 선언
                              /* final Map<String, String> leaveTypeMap = {
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
                                  leaveTypeMap[rawType] ?? rawType; */

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              LeaveRequestDetailScreen(
                                                  requestId: item.requestId),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 10, 16, 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: AppColors.divider),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          //첫번째 줄
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        '${item.employeeName} ${item.position}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        item.team,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .textMuted,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              // 고정
                                              LeaveStatusBadge(
                                                  status: item.status),
                                            ],
                                          ),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
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
                                          Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.baseline,
                                              textBaseline:
                                                  TextBaseline.alphabetic,
                                              children: [
                                                const SizedBox(height: 10),
                                                Text(
                                                    '신청일 : ${DateFormat('yyyy.MM.dd').format(DateTime.parse(item.requestedAt))}',
                                                    style: const TextStyle(
                                                        color:
                                                            AppColors.textMuted,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                const SizedBox(width: 12),
                                                const Spacer(),
                                                if (_isCancelable(item,
                                                    userEmployeeNumber)) ...[
                                                  TextButton(
                                                    onPressed: isProcessing
                                                        ? null
                                                        : () => _confirmCancel(
                                                            item),
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 4,
                                                          vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    child: isProcessing
                                                        ? const SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: AppColors
                                                                  .textMuted,
                                                            ),
                                                          )
                                                        : const Text(
                                                            '신청 취소',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: AppColors
                                                                  .textMuted,
                                                              decoration:
                                                                  TextDecoration
                                                                      .underline,
                                                              decorationColor:
                                                                  AppColors
                                                                      .textMuted,
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
