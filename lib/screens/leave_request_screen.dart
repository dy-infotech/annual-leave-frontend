import 'package:annual_leave_frontend/providers/public_holiday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/enums/LeaveState.dart';
import '../models/enums/LeaveType.dart';
import '../providers/auth_provider.dart';
import '../providers/leave_request_list_provider.dart';
import '../services/api_client.dart';
import '../models/leave_request_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  DateTime _focusedDay = DateTime.now();
  LeaveType _selectedLeaveType = LeaveType.full;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _leaveReason;
  final _useDaysController = TextEditingController(text: '0');
  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _useDays => double.tryParse(_useDaysController.text) ?? 0;

  // 사유 입력란 필요 여부 (연차, 반차 제외한 나머지)
  bool get _needsReason => ![
        LeaveType.full,
        LeaveType.amHalf,
        LeaveType.pmHalf,
      ].contains(_selectedLeaveType);

  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 직후 실행되도록 addPostFrameCallback 사용
    // (initState 시점에는 아직 위젯 트리가 완성되지 않아 context 사용이 불안정할 수 있음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 캘린더에 별표를 표시하기 위해, 화면 진입 시 내 휴가 신청 목록을 한 번만 조회
      // (구독이 아닌 단발성 호출이라 watch가 아닌 read 사용)
      context.read<LeaveRequestListProvider>().fetchMyLeaveRequestList();
    });
    context.read<AuthProvider>().fetchMyInfo();
  }

  // 주말 + 공휴일 제외하고 계산
  int _calculateUsableDays(PublicHolidayProvider holidayProvider) {
    if (_startDate == null || _endDate == null) return 0;
    int count = 0;
    DateTime cursor = _startDate!;
    while (!cursor.isAfter(_endDate!)) {
      final isWeekend = cursor.weekday == DateTime.saturday ||
          cursor.weekday == DateTime.sunday;
      final isHoliday = holidayProvider.isHoliday(cursor);
      if (!isWeekend && !isHoliday) count++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  @override
  void dispose() {
    _useDaysController.dispose();
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final holidayProvider = context.read<PublicHolidayProvider>();

    bool rangeConfirmed = false;

    setState(() {
      _focusedDay = focusedDay;

      // 날짜를 새로 선택하면 이전 에러 메시지 제거
      _errorMessage = null;

      final isHalfDay = _selectedLeaveType == LeaveType.amHalf || _selectedLeaveType == LeaveType.pmHalf;

      if (isHalfDay) {
        _startDate = selectedDay;
        _endDate = selectedDay;
        _useDaysController.text = '0.5';
        rangeConfirmed = true;
      } else if (_startDate == null ||
          (_startDate != null && _endDate != null)) {
        _startDate = selectedDay;
        _endDate = null;
        _useDaysController.text = '0';
      } else if (selectedDay.isBefore(_startDate!)) {
        _startDate = selectedDay;
        _useDaysController.text = '0';
      } else {
        _endDate = selectedDay;
        _useDaysController.text =
            _calculateUsableDays(holidayProvider).toString();
        rangeConfirmed = true;
      }
    });

    // 종료일(또는 반차 단일일) 확정 시 조기 확인 (이미 로드된 목록으로, 재호출 없이)
    if (rangeConfirmed) {
      _checkOverlapAndWarn();
    }
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null) {
      return false;
    }

    final end = _endDate ?? _startDate!;
    return !day.isBefore(_startDate!) && !day.isAfter(end);
  }

  Future<void> _handleSubmit() async {
    final authProvider = context.read<AuthProvider>();
    final listProvider = context.read<LeaveRequestListProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (_startDate == null || _endDate == null) {
      setState(() => _errorMessage = '날짜를 선택해주세요.');
      return;
    }

    if (_useDays <= 0) {
      setState(() => _errorMessage = '사용 일수가 변경되지 않았습니다. 날짜를 다시 선택해 주세요.');
      return;
    }

    // 기존 대기/승인 신청과 기간이 겹치는지 확인
    if (await _checkOverlapAndWarn(refresh: true)) {
      return; // 다이얼로그 닫히면 제출을 진행하지 않고 종료
    }

    // 최종 확인 다이얼로그
    if (!await _confirmSubmit()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final request = LeaveRequestCreate(
        leaveType: _selectedLeaveType.code,
        startDate: _startDate!,
        endDate: _endDate ?? _startDate!,
        useDays: _useDays,
        leaveReason: _leaveReason,
      );

      await ApiClient().dio.post('/api/leave-requests', data: request.toJson());

    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.');
      }
      return; // 신청 실패 시 여기서 종료 (갱신 또는 초기화 진행 안 함)

    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // 신청 성공 이후 처리
    messenger.showSnackBar(
      const SnackBar(content: Text('휴가 신청이 완료되었습니다.')),
    );

    // 데이터 갱신
    try {
      await authProvider.fetchMyInfo(); // 잔여 연차 차감 반영
      await listProvider.fetchMyLeaveRequestList(); // 캘린더 별표 반영
    } catch (_) {
      // 이 시점에서 신청은 완료됐기 때문에 갱신 실패의 경우 무시
    }

    // 선택한 상태 초기화
    if (mounted) {
      setState(() {
        _startDate = null;
        _endDate = null;
        _useDaysController.text = '0';
        _selectedLeaveType = LeaveType.full;
        _reasonController.clear();
        _leaveReason = null;
      });
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  // 별의 왼쪽(오전) 또는 오른쪽(오후) 절반만 그리기
  // Widget _buildHalfStar({required bool isLeft, Color color = Colors.yellow, double size = 32,}) {
  //   return ClipRect(
  //     clipper: _HalfClipper(isLeft: isLeft),
  //     child: Icon(Icons.star_rounded, size: size, color: color),
  //   );
  // }

  // Widget _buildHalfStar({required bool isLeft, IconData icon = Icons.star_rounded, double size = 32,}) {
  //   return ClipRect(
  //     clipper: _HalfClipper(isLeft: isLeft),
  //     child: Icon(icon, size: size, color: Colors.yellow), // 색은 노랑 통일
  //   );
  // }

  Widget _buildHalfStar({required bool isLeft, bool glow = false, double size = 32,}) {
    return ClipRect(
      clipper: _HalfClipper(isLeft: isLeft),
      child: Icon(
        Icons.star_rounded,
        size: size,
        color: Colors.yellow,
        shadows: glow
            ? [const Shadow(color: Colors.yellow, blurRadius: 8)]
            : null,
      ),
    );
  }

  // 상태에 따른 별 색상 (승인=노랑, 대기=회색)
  Color _starColor(String? status) {
    if (status == LeaveState.approved.code) {
      return Colors.yellow; // 승인
    }
    return const Color(0xFFBDBDBD); // 대기
  }

  // 상태에 따른 별 아이콘 (승인=채운 별, 대기=테두리 별)
  IconData _starIcon(String? status) {
    if (status == LeaveState.approved.code) {
      return Icons.star_rounded;  // 승인
    }
    return Icons.star_border_rounded; // 대기
  }

  // 승인 건에 은은한 글로우를 준 별 아이콘
  Widget _glowStar(String? status, {double size = 32}) {
    final isApproved = status == LeaveState.approved.code;

    return Icon(
      Icons.star_rounded,
      size: size,
      color: Colors.yellow,

      shadows: isApproved
          ? [
        const Shadow(color: Color(0xFFFF9800), blurRadius: 10), // 주황 글로우
        const Shadow(color: Color(0xFFFFC107), blurRadius: 5),
      ]
          : null,

      // shadows: isApproved
      //     ? [
      //   // 승인: 노란빛이 부드럽게 번지는 글로우
      //   const Shadow(
      //     color: Colors.yellow,
      //     blurRadius: 8,
      //   ),
      //   const Shadow(
      //     color: Color(0xFFFFE082), // 연한 노랑으로 한 겹 더
      //     blurRadius: 4,
      //   ),
      // ]
      //     : null, // 대기: 글로우 없음
    );
  }

  Widget _buildDayCell({
    required int day,
    required Color? backgroundColor,
    required Color textColor,
    required String? amStatus,   // 오전 상태 (null이면 없음)
    required String? pmStatus,   // 오후 상태
    bool isToday = false,
  }) {
    final hasAm = amStatus != null;
    final hasPm = pmStatus != null;
    final isRequested = hasAm || hasPm;

    // Widget buildStar() {
    //   if (hasAm && hasPm) {
    //     if (amStatus == pmStatus) {
    //       // 오전/오후 상태 동일 -> 단색 온전한 별
    //       return Icon(Icons.star_rounded, size: 32, color: _starColor(amStatus));
    //     } else {
    //       // 상태 다름 -> 좌(오전)/우(오후) 색 분리
    //       return Stack(
    //         children: [
    //           _buildHalfStar(isLeft: true, color: _starColor(amStatus)),
    //           _buildHalfStar(isLeft: false, color: _starColor(pmStatus)),
    //         ],
    //       );
    //     }
    //   } else if (hasAm) {
    //     return _buildHalfStar(isLeft: true, color: _starColor(amStatus));
    //   } else {
    //     return _buildHalfStar(isLeft: false, color: _starColor(pmStatus));
    //   }
    // }

    // Widget buildStar() {
    //   if (hasAm && hasPm) {
    //     if (amStatus == pmStatus) {
    //       // 오전/오후 상태 동일 -> 단색 온전한 별 (채움 or 테두리)
    //       return Icon(_starIcon(amStatus), size: 32, color: Colors.yellow);
    //     } else {
    //       // 상태 다름 -> 좌(오전)/우(오후) 아이콘 분리
    //       return Stack(
    //         children: [
    //           _buildHalfStar(isLeft: true, icon: _starIcon(amStatus)),
    //           _buildHalfStar(isLeft: false, icon: _starIcon(pmStatus)),
    //         ],
    //       );
    //     }
    //   } else if (hasAm) {
    //     return _buildHalfStar(isLeft: true, icon: _starIcon(amStatus));
    //   } else {
    //     return _buildHalfStar(isLeft: false, icon: _starIcon(pmStatus));
    //   }
    // }

    Widget buildStar() {
      final amApproved = amStatus == LeaveState.approved.code;
      final pmApproved = pmStatus == LeaveState.approved.code;

      if (hasAm && hasPm) {
        if (amStatus == pmStatus) {
          // 상태 동일 -> 온전한 별 (승인이면 글로우)
          return _glowStar(amStatus);
        } else {
          // 상태 다름 -> 좌우 분리, 각각 승인 여부로 글로우
          return Stack(
            children: [
              _buildHalfStar(isLeft: true, glow: amApproved),
              _buildHalfStar(isLeft: false, glow: pmApproved),
            ],
          );
        }
      } else if (hasAm) {
        return _buildHalfStar(isLeft: true, glow: amApproved);
      } else {
        return _buildHalfStar(isLeft: false, glow: pmApproved);
      }
    }

    final Widget body = isRequested
        ? Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          buildStar(),
          Text(
            '$day',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    )
        : Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      ),
    );

    if (!isToday) return body;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          bottom: 3,
          child: Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  // 중복 신청 여부 확인 후, 겹치면 안내 다이얼로그를 띄우고 true 반환
  Future<bool> _checkOverlapAndWarn({bool refresh = false}) async {
    if (_startDate == null) return false;

    final listProvider = context.read<LeaveRequestListProvider>();
    if (refresh) {
      await listProvider.fetchMyLeaveRequestList();
    }
    final effectiveEndDate = _endDate ?? _startDate!;

    if (!listProvider.hasOverlap(_startDate!, effectiveEndDate, _selectedLeaveType.code)) {
      return false;
    }

    if (!mounted) return true;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('중복 신청 안내',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text(
          '해당 기간에 이미 대기 중이거나 승인된 휴가 신청이 있습니다.\n기간을 다시 확인해주세요.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인',
                style: TextStyle(
                    color: AppColors.slate, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return true;
  }

  // 신청 전 최종 확인 다이얼로그
  Future<bool> _confirmSubmit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('휴가 신청 확인',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('아래 내용으로 신청하시겠습니까?',
                style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 14),
            _confirmRow('휴가 종류', _selectedLeaveType.label),
            const SizedBox(height: 6),
            _confirmRow(
              '기간',
              _endDate == null || _startDate == _endDate
                  ? _formatDate(_startDate!)
                  : '${_formatDate(_startDate!)} ~ ${_formatDate(_endDate!)}',
            ),
            const SizedBox(height: 6),
            _confirmRow('사용 연차', '${_useDaysController.text}일'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(
                    color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('신청',
                style: TextStyle(
                    color: AppColors.slate, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result ?? false; // 바깥 탭으로 닫히면 false
  }

 // 확인 다이얼로그 내부의 한 줄 (라벨 + 값)
  Widget _confirmRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>().employeeInfo;
    final holidayProvider = context.watch<PublicHolidayProvider>();
    final leaveReqProvider = context.watch<LeaveRequestListProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('휴가 신청')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 신청자 / 결재자 (좌우 대칭 배치)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 신청자
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('신청자',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.slate),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              // children: [
                              //   Text(
                              //     authProvider != null
                              //         ? '${authProvider.name} ${authProvider.position} ${authProvider.department}'
                              //         : '',
                              //     overflow: TextOverflow.ellipsis,
                              //     style: const TextStyle(
                              //         fontSize: 15,
                              //         fontWeight: FontWeight.w800,
                              //         color: AppColors.textPrimary),
                              //   ),
                              //   const SizedBox(height: 3),
                              //   // Text(
                              //   //   '${authProvider?.department ?? ''} · ${authProvider?.employeeNumber ?? ''}',
                              //   //   overflow: TextOverflow.ellipsis,
                              //   //   style: const TextStyle(
                              //   //       fontSize: 12, color: AppColors.textMuted),
                              //   // ),
                              // ],
                              children: [
                                if (authProvider != null)
                                  Row(
                                    children: [
                                      // 이름과 직급 (좌측 고정, 크고 진하게)
                                      Text(
                                        '${authProvider.name} ${authProvider.position}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary),
                                      ),

                                      // 중간 빈 공간을 다 차지하여 부서 정보를 우측 끝으로 밀어냄
                                      const Expanded(child: SizedBox()),

                                      // 부서 정보 (우측 끝 고정, 작고 연하게)
                                      Text(
                                        authProvider.department,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w400),
                                      ),
                                      const SizedBox(width: 4), // 우측 테두리와의 최소 여백
                                    ],
                                  ),
                                const SizedBox(height: 3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 결재자
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('결재자',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Stack(
                            fit: StackFit.passthrough,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (authProvider != null)
                                      Row(
                                        children: [
                                          // 이름과 직급 (좌측 고정, 크고 진하게)
                                          Text(
                                            '${authProvider.approverName} ${authProvider.approverPosition}',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary),
                                          ),

                                          // 중간 빈 공간을 다 차지하여 부서 정보를 우측 끝으로 밀어냄
                                          const Expanded(child: SizedBox()),

                                          // 부서 정보 (우측 끝 고정, 작고 연하게)
                                          Text(
                                            authProvider.department,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.w400),
                                          ),
                                          const SizedBox(width: 4), // 우측 테두리와의 최소 여백
                                        ],
                                      ),
                                    const SizedBox(height: 3),
                                  ],
                                ),
                              ),

                              // 우측 상단 호버 툴팁
                              Positioned(
                                top: 0,
                                right: 0,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.help,
                                  child: Tooltip(
                                    message: 'PL은 0xFFC9A66B를 원했으나, 망막 보호를 위해 0xFF2B3A4A를 적용함',
                                    triggerMode: TooltipTriggerMode.tap,
                                    showDuration: const Duration(seconds: 3),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 인라인 캘린더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '신청 기간',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(width: 10),

                // Expanded를 조건문 바깥으로 빼서 날짜가 없어도 항상 공간을 차지
                Expanded(
                  child: _startDate != null
                      ? Text(
                          _endDate == null
                              ? '${_formatDate(_startDate!)} 선택됨 · 종료일을 눌러주세요'
                              : '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600),
                        )
                      : const SizedBox(), // 날짜가 없을 때는 빈 공간으로 채워 우측 텍스트를 밀어냄
                ),

                // 우측 끝에 완전히 고정되는 잔여 연차 표시
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Text(
                    '잔여 ${authProvider?.remainingLeaveDays ?? 0}일',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TableCalendar(
                locale: 'ko_KR',
                rowHeight: 42, // 기본 52 > 42
                daysOfWeekHeight: 22, // 기존 28 > 22 (요일 헤더도 축소)
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: AppColors.textMuted,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: AppColors.coral),
                  defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                  todayDecoration: BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selectedDayPredicate: (day) =>
                    _startDate != null && isSameDay(day, _startDate) ||
                    _endDate != null && isSameDay(day, _endDate),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final isHoliday = holidayProvider.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;

                    // 오전/오후 휴가 상태 조회
                    final half = (isGrayed == false)
                        ? leaveReqProvider.halfDayStatus(day)
                        : (amStatus: null, pmStatus: null);

                    if (_isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor:
                        isGrayed ? Colors.grey.withOpacity(0.3) : AppColors.slate,
                        textColor: isGrayed ? AppColors.textMuted : Colors.white,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                      );
                    }

                    if (isHoliday || half.amStatus != null || half.pmStatus != null) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: null,
                        textColor: isHoliday ? AppColors.coral : AppColors.textPrimary,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                      );
                    }

                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isHoliday = holidayProvider.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;

                    // 오전/오후 휴가 상태 조회
                    final half = (isGrayed == false)
                        ? leaveReqProvider.halfDayStatus(day)
                        : (amStatus: null, pmStatus: null);

                    // 선택된 범위 안의 오늘: 슬레이트 배경 유지 + 빨간 밑줄
                    if (_isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor:
                        isGrayed ? Colors.grey.withOpacity(0.3) : AppColors.slate,
                        textColor: isGrayed ? AppColors.textMuted : Colors.white,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                        isToday: true,
                      );
                    }

                    // 범위 밖의 오늘: 원형 배경 없이 숫자 + 빨간 밑줄
                    return _buildDayCell(
                      day: day.day,
                      backgroundColor: null,
                      textColor: isGrayed ? AppColors.coral : AppColors.textPrimary,
                      amStatus: half.amStatus,
                      pmStatus: half.pmStatus,
                      isToday: true,
                    );
                  },
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
            ),

            const SizedBox(height: 16),

            // 휴가 종류 / 사용할 연차 개수
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 휴가 종류 셀렉트 박스
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('휴가 종류',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<LeaveType>(
                            value: _selectedLeaveType,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: AppColors.textMuted),
                            items: LeaveType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type.label,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final wasHalfDay = _selectedLeaveType == LeaveType.amHalf || _selectedLeaveType == LeaveType.pmHalf;
                                final isHalfDay = value == LeaveType.amHalf || value == LeaveType.pmHalf;
                                final willShowReason = ![
                                  LeaveType.full,
                                  LeaveType.amHalf,
                                  LeaveType.pmHalf,
                                ].contains(value);

                                setState(() {
                                  _selectedLeaveType = value;

                                  if (isHalfDay) {
                                    // 시작일과 종료일이 다르면 (1일 초과 선택된 상태라면) 초기화
                                    if (_startDate != null && _endDate != null && _startDate != _endDate) {
                                      _startDate = null;
                                      _endDate = null;
                                      _useDaysController.text = '0';
                                    }
                                    // 정확히 하루만 선택되어 있었다면 반차(0.5일) 기간으로 동기화
                                    else if (_startDate != null) {
                                      _endDate = _startDate; // 시작일과 종료일을 같게 설정
                                      _useDaysController.text = '0.5';
                                    }
                                    // 날짜가 아예 선택되지 않은 상태라면 사용일수만 0.5로 설정
                                    else {
                                      _useDaysController.text = '0.5';
                                    }
                                  } else if (wasHalfDay) {
                                    // 반차에서 일반 휴가로 바꿀 때, 기존에 선택된 날짜가 있다면 사용일수 재계산
                                    if (_startDate != null) {
                                      // 이미 하루 이상 선택되어 있다면 종료일 확인 후 재계산 (holidayProvider 필요)
                                      _useDaysController
                                          .text = _calculateUsableDays(context
                                              .read<PublicHolidayProvider>())
                                          .toString();
                                    } else {
                                      _useDaysController.text = '0';
                                    }
                                  }
                                });

                                if (willShowReason) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollController.animateTo(
                                      _scrollController
                                          .position.maxScrollExtent,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 사용할 연차 개수
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('사용 연차',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      Container(
                        height: 50,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.divider.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '${_useDaysController.text} 일',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 사유 입력란 (연차/반차 외 항목 선택 시에만 표시)
            if (_needsReason) ...[
              const Text('사유',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '휴가 사유를 입력해주세요',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.coral, fontSize: 13),
              ),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('신청하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  final bool isLeft;
  _HalfClipper({required this.isLeft});

  @override
  Rect getClip(Size size) {
    return isLeft
        ? Rect.fromLTRB(0, 0, size.width / 2, size.height)  // 왼쪽 절반
        : Rect.fromLTRB(size.width / 2, 0, size.width, size.height);  // 오른쪽 절반
  }

  @override
  bool shouldReclip(_HalfClipper old) => old.isLeft != isLeft;
}