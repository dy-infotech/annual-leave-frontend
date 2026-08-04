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
          initialRange: _dateRange,
        ),
      ),
    );

    if (picked != null) {
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
            height: 60,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.25,
                    height: 40, // 원하는 높이로 조절
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // 흰 바탕
                        border: Border.all(
                            color: Colors.grey.shade300), // 옅은 회색 테두리
                        borderRadius: BorderRadius.circular(8), // 모서리 약간 둥글게
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8), // 안쪽 여백
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
                  const Spacer(), // 드롭다운과 버튼 그룹 사이 넓은 공간 확보
                  Row(
                    children: [
                      // UI 코드 예시: 라디오 버튼 목록 만들기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: searchFilterList.map((item) {
                          final label = item['label']!;
                          return Padding(
                            // '전체' 글자와 '내 신청' 아이콘이 붙지 않도록 오른쪽에만 여백을 줍니다.
                            padding: const EdgeInsets.only(right: 10.0),
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
                                // 3. 기본 여백이 사라졌으므로, 원하는 만큼만 미세하게 간격(4px)을 지정합니다.
                                const SizedBox(width: 2),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
              // 1. 메인 축 정렬을 우측 정렬로 설정합니다.
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 💡 실제 리스트 데이터인 _items의 길이를 가져와 동적으로 건수를 표시합니다. (조회건수)

                Text(
                  '조회건수: ${_items.length}건',
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

                                        // 4. 중간 빈 공간을 전부 채워서 배지를 오른쪽 끝으로 밀어냅니다
                                        const Spacer(),
                                        LeaveStatusBadge(status: item.status),
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
                                          Text(
                                              '(${item.useDays}일) [${leaveTypeNm}]',
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
                                          const SizedBox(width: 12),
                                          // 1. 중간 빈 공간을 자동으로 가득 채워 우측 버튼을 끝으로 밀어냅니다.
                                          const Spacer(),
                                          if (_isCancelable(
                                              item, userEmployeeNumber)) ...[
                                            // 2. Row 내부에 굳이 필요 없는 Divider와 큰 SizedBox, Align 위젯을 제거하여 레이아웃을 단순화합니다.
                                            TextButton(
                                              onPressed: isProcessing
                                                  ? null
                                                  : () => _confirmCancel(item),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    )
                                                  : const Text(
                                                      '신청 취소',
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.textMuted,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        decorationColor:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                            ),
                                          ],
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
