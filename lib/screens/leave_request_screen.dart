import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/enums/LeaveType.dart';
import '../providers/auth_provider.dart';
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

  int get _weekdayCount {
    if (_startDate == null || _endDate == null) return 0;
    int count = 0;
    DateTime cursor = _startDate!;
    while (!cursor.isAfter(_endDate!)) {
      if (cursor.weekday != DateTime.saturday && cursor.weekday != DateTime.sunday) count++;
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
    setState(() {
      _focusedDay = focusedDay;

      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // 새로 범위 선택 시작
        _startDate = selectedDay;
        _endDate = null;

      } else if (selectedDay.isBefore(_startDate!)) {
        // 시작일보다 이전 날짜를 누르면 시작일 갱신
        _startDate = selectedDay;

      } else {
        _endDate = selectedDay;
        _useDaysController.text = _weekdayCount.toString();
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('휴가 신청이 완료되었습니다.')));
        Navigator.pop(context);
      }

    } catch (e) {
      setState(() => _errorMessage = '신청 중 오류가 발생했습니다. 입력값을 확인해주세요.');

    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final info = context.watch<AuthProvider>().employeeInfo;

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
                    info != null ? '${info.name} ${info.position}  ' : '',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7), // 이 부분이 상단 패딩임
                    child: Text(
                      '${info?.department ?? ''} · ${info?.employeeNumber ?? ''}',
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
            const Text('신청 기간', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                  titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textMuted),
                  rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textMuted),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  weekendStyle: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600),
                ),
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: AppColors.coral),
                  defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                  todayDecoration: BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                selectedDayPredicate: (day) =>
                _startDate != null && isSameDay(day, _startDate) ||
                    _endDate != null && isSameDay(day, _endDate),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    if (_isInRange(day)) {
                      final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isWeekend                      // 주말인지 확인
                              ? Colors.grey.withOpacity(0.3)    // 주말이면 회색
                              : AppColors.slate,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isWeekend                     // 주말인지 확인
                                ? AppColors.textMuted            // 주말 텍스트 색상
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    if (_isInRange(day)) {
                      final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

                      // 범위 안에 포함된 오늘 → 다른 선택된 날짜와 동일하게 표시
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isWeekend
                              ? Colors.grey.withOpacity(0.3)
                              : AppColors.slate,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isWeekend ? AppColors.textMuted : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }

                    // 범위에 포함 안 된 오늘 → 기존 amber 스타일 유지
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
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
                          : '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}  (평일 $_weekdayCount일)',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),

                  const Spacer(),

                  // 휴가 정보 (남은/총 휴가일수)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '3',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate),
                        ),
                        TextSpan(
                          text: ' / 15 일',
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
                                final willShowReason = ![
                                  LeaveType.full,
                                  LeaveType.amHalf,
                                  LeaveType.pmHalf,
                                ].contains(value);

                                setState(() => _selectedLeaveType = value);

                                if (willShowReason) {
                                  // 위젯 트리가 리빌드된 다음 프레임에 스크롤 실행
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
                      TextField(
                        controller: _useDaysController,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(suffixText: '일'),
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

            // 결재자 정보 (항상 표시)
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                    info != null ? '${info.name} ${info.position}  ' : '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.coral, fontSize: 13)),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('신청하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}