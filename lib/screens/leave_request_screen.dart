import 'package:annual_leave_frontend/providers/public_holiday_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
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
  }

  // 주말 + 공휴일 제외하고 계산
  int _calculateUsableDays(PublicHolidayProvider holidayProvider) {
    if (_startDate == null || _endDate == null) return 0;
    int count = 0;
    DateTime cursor = _startDate!;
    while (!cursor.isAfter(_endDate!)) {
      final isWeekend = cursor.weekday == DateTime.saturday || cursor.weekday == DateTime.sunday;
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
    // Provider 접근 (계산에 필요)
    final holidayProvider = context.read<PublicHolidayProvider>();

    setState(() {
      _focusedDay = focusedDay;

      final isHalfDay = _selectedLeaveType == LeaveType.amHalf ||
          _selectedLeaveType == LeaveType.pmHalf;

      if (isHalfDay) {
        // 반차인 경우 (시작일 = 종료일), 항상 단일 날짜로 선택
        _startDate = selectedDay;
        _endDate = selectedDay;
        _useDaysController.text = '0.5';

      } else if (_startDate == null || (_startDate != null && _endDate != null)) {
        // 새로 범위 선택 시작
        _startDate = selectedDay;
        _endDate = null;
        _useDaysController.text = '0';

      } else if (selectedDay.isBefore(_startDate!)) {
        // 시작일보다 이전 날짜를 누르면 시작일 갱신
        _startDate = selectedDay;
        _useDaysController.text = '0';

      } else {
        _endDate = selectedDay;
        // 공휴일 반영된 계산 메서드 사용
        _useDaysController.text = _calculateUsableDays(holidayProvider).toString();
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null) {
      return false;
    }

    final end = _endDate ?? _startDate!;
    return !day.isBefore(_startDate!) && !day.isAfter(end);
  }

  Future<void> _handleSubmit() async {
    if (_startDate == null) {
      setState(() => _errorMessage = '날짜를 선택해주세요.');
      return;
    }

    if (_useDays <= 0) {
      setState(() => _errorMessage = '사용일수를 입력해주세요.');
      return;
    }

    // 기존 대기/승인 신청과 기간이 겹치는지 확인
    final listProvider = context.read<LeaveRequestListProvider>();
    await listProvider.fetchMyLeaveRequestList();
    final effectiveEndDate = _endDate ?? _startDate!;

    if (listProvider.hasOverlap(_startDate!, effectiveEndDate)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('중복 신청 안내', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: const Text(
            '해당 기간에 이미 대기 중이거나 승인된 휴가 신청이 있습니다.\n기간을 다시 확인해주세요.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return; // 다이얼로그 닫히면 제출을 진행하지 않고 종료
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

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('휴가 신청이 완료되었습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = '신청 중 오류가 발생했습니다. 입력값을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  // 날짜 셀 하나를 그리는 공통 위젯 (원 배경 + 숫자 + 필요 시 별표)
  // Widget _buildDayCell({
  //   required int day,
  //   required Color? backgroundColor,
  //   required Color textColor,
  //   required bool isRequested,
  // }) {
  //   return Stack(
  //     clipBehavior: Clip.none,
  //     children: [
  //       Container(
  //         margin: const EdgeInsets.all(4),
  //         decoration: BoxDecoration(
  //           color: backgroundColor,
  //           shape: BoxShape.circle,
  //         ),
  //         alignment: Alignment.center,
  //         child: Text(
  //           '$day',
  //           style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
  //         ),
  //       ),
  //       if (isRequested)
  //         const Positioned(
  //           top: 0,
  //           right: 2,
  //           child: Icon(Icons.star, size: 10, color: AppColors.amber),
  //         ),
  //     ],
  //   );
  // }

  Widget _buildDayCell({
    required int day,
    required Color? backgroundColor,
    required Color textColor,
    required bool isRequested,
    bool isToday = false,
  }) {
    if (isRequested) {
      return Container(
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 40,
              color: Colors.yellow,
            ),
            Text(
              '$day',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (isToday)  // 오늘
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.coral, // 주말과 동일한 빨간 계열
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(4),
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
            // 사용자 정보 카드
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider != null ? '${authProvider.name} ${authProvider.position}  ' : '',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      '${authProvider?.department ?? ''} · ${authProvider?.employeeNumber ?? ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 인라인 캘린더
            const Text(
              '신청 기간',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
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
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                daysOfWeekHeight: 28,
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
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;
                    final isRequested = (isGrayed == false) && leaveReqProvider.isRequestedDate(day);

                    if (_isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed ? Colors.grey.withOpacity(0.3) : AppColors.slate,
                        textColor: isGrayed ? AppColors.textMuted : Colors.white,
                        isRequested: isRequested,
                      );
                    }

                    // 범위 밖이지만 공휴일이거나 신청된 날짜인 경우
                    if (isHoliday || isRequested) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: null,
                        textColor: isHoliday ? AppColors.coral : AppColors.textPrimary,
                        isRequested: isRequested,
                      );
                    }

                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isHoliday = holidayProvider.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;
                    final isRequested = (isGrayed == false) && leaveReqProvider.isRequestedDate(day);

                    if (_isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed ? Colors.grey.withOpacity(0.3) : AppColors.slate,
                        textColor: isGrayed ? AppColors.textMuted : Colors.white,
                        isRequested: isRequested,
                        isToday: true,
                      );
                    }

                    return _buildDayCell(
                      day: day.day,
                      backgroundColor: AppColors.amber,
                      textColor: Colors.white,
                      isRequested: isRequested,
                      isToday: true,
                    );
                  },
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 선택된 날짜 범위 텍스트
                  if (_startDate != null)
                    Text(
                      _endDate == null
                          ? '${_formatDate(_startDate!)} 선택됨 · 종료일을 눌러주세요'
                          : '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),

                  const Spacer(),

                  // 휴가 정보 (남은/총 휴가일수)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${authProvider?.remainingLeaveDays ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate),
                        ),
                        TextSpan(
                          text: ' / ${authProvider?.currTotalLeaveDays ?? 0} 일',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 휴가 종류 및 사용할 연차 개수
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 휴가 종류 셀렉트 박스
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('휴가 종류', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<LeaveType>(
                            value: _selectedLeaveType,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                            items: LeaveType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type.label,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final wasHalfDay = _selectedLeaveType == LeaveType.amHalf ||
                                    _selectedLeaveType == LeaveType.pmHalf;
                                final isHalfDay = value == LeaveType.amHalf || value == LeaveType.pmHalf;

                                final willShowReason = ![
                                  LeaveType.full,
                                  LeaveType.amHalf,
                                  LeaveType.pmHalf,
                                ].contains(value);

                                setState(() {
                                  _selectedLeaveType = value;

                                  if (isHalfDay) {
                                    _useDaysController.text = '0.5';
                                  } else if (wasHalfDay) {
                                    _useDaysController.text = '0';
                                  }
                                });

                                if (willShowReason) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollController.animateTo(
                                      _scrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
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

                const SizedBox(width: 16),

                // 사용할 연차 개수
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('사용할 연차 개수', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          // color: AppColors.surface,
                          color: AppColors.divider.withOpacity(0.3), // surface보다 톤다운
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '${_useDaysController.text} 일',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 사유 입력란 (연차/반차 외 항목 선택 시에만 표시)
            if (_needsReason) ...[
              const SizedBox(height: 16),
              const Text('사유', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '휴가 사유를 입력해주세요',
                  hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.6)),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],

            // 결재자 정보
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                // color: AppColors.surface,
                color: AppColors.divider.withOpacity(0.3), // surface보다 톤다운
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Text(
                    '결재자',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    authProvider != null ? '${authProvider.approverName} ${authProvider.approverPosition}  ' : '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.coral, fontSize: 13),
              ),
            ],

            const SizedBox(height: 32),
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