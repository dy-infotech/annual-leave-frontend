import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
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
  DateTime? _startDate;
  DateTime? _endDate;
  final _useDaysController = TextEditingController(text: '0');
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _useDays => double.tryParse(_useDaysController.text) ?? 0;

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

  void _addFullDay() {
    setState(() {
      final current = _useDays + 1.0;
      _useDaysController.text = _formatDays(current);
    });
  }

  void _addHalfDay() {
    setState(() {
      final current = _useDays + 0.5;
      _useDaysController.text = _formatDays(current);
    });
  }

  void _resetDays() {
    setState(() => _useDaysController.text = '0');
  }

  String _formatDays(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
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
        startDate: _startDate!,
        endDate: _endDate ?? _startDate!,
        useDays: _useDays,
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // 사용자 정보 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.slate,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info != null ? '${info.name} ${info.position}' : '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info?.department ?? ''} · ${info?.employeeNo ?? ''}',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
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
                      final isEdge = (_startDate != null && isSameDay(day, _startDate)) ||
                          (_endDate != null && isSameDay(day, _endDate));
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isEdge ? AppColors.slate : AppColors.slate.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isEdge ? Colors.white : AppColors.slate,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
            ),
            if (_startDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 4),
                child: Text(
                  _endDate == null
                      ? '${_formatDate(_startDate!)} 선택됨 · 종료일을 눌러주세요'
                      : '${_formatDate(_startDate!)} — ${_formatDate(_endDate!)}  (평일 $_weekdayCount일)',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 28),

            // 연차/반차 버튼 + 직접 입력
            const Text('사용할 연차 개수', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DayButton(label: '연차 +1.0', onTap: _addFullDay),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DayButton(label: '반차 +0.5', onTap: _addHalfDay, filled: false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _useDaysController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(suffixText: '일'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _resetDays,
                  child: const Text('초기화', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('버튼으로 더하거나, 직접 숫자를 입력할 수 있습니다.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
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

class _DayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _DayButton({required this.label, required this.onTap, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? AppColors.slate : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate, width: 1.3),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: filled ? Colors.white : AppColors.slate,
          ),
        ),
      ),
    );
  }
}