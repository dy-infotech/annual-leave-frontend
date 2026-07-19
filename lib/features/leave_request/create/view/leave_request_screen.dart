import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/network/api_client.dart';
import '../../../profile/viewmodel/profile_viewmodel.dart';
import '../../../public_holiday/viewmodel/public_holiday_viewmodel.dart';
import '../../common/model/api_client/leave_request_common_api_client.dart';
import '../model/enum/leave_type.dart';
import '../model/api_client/leave_request_create_api_client.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_drawer.dart';
import '../viewmodel/leave_request_create_viewmodel.dart';

// 이 화면 전용 ViewModel이라 화면을 감싸는 지점에서 scoped로 생성한다.
// PublicHolidayViewModel(공휴일)과 ProfileViewModel(내 정보)은 전역 상태라
// main.dart에 이미 등록되어 있으므로 그대로 구독만 한다.
class LeaveRequestScreen extends StatelessWidget {
  const LeaveRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaveRequestCreateViewModel(
        LeaveRequestCreateApiClient(ApiClient()),
        LeaveRequestCommonApiClient(ApiClient()),
      ),
      child: const _LeaveRequestView(),
    );
  }
}

class _LeaveRequestView extends StatefulWidget {
  const _LeaveRequestView();

  @override
  State<_LeaveRequestView> createState() => _LeaveRequestViewState();
}

class _LeaveRequestViewState extends State<_LeaveRequestView> {
  DateTime _focusedDay = DateTime.now();
  final _reasonController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 첫 프레임이 그려진 직후, 캘린더 별표 표시 + 겹침 검사를 위해 내 목록을 한 번 조회
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveRequestCreateViewModel>().loadMyItemsForOverlapCheck();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final vm = context.read<LeaveRequestCreateViewModel>();
    vm.leaveReason = _reasonController.text;

    try {
      final success = await vm.submit();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('휴가 신청이 완료되었습니다.')));
        Navigator.pop(context);
      }
    } on LeaveOverlapException {
      if (!mounted) return;
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
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

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
            const Icon(Icons.star_rounded, size: 40, color: Colors.yellow),
            Text(
              '$day',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            if (isToday)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.coral),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(day.toString(), style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaveRequestCreateViewModel>();
    final info = context.watch<ProfileViewModel>().employeeInfo;
    final holidayVm = context.watch<PublicHolidayViewModel>();

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
              decoration: BoxDecoration(color: AppColors.slate, borderRadius: BorderRadius.circular(20)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info != null ? '${info.name} ${info.position}  ' : '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      '${info?.department ?? ''} · ${info?.employeeNumber ?? ''}',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                  todayDecoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                selectedDayPredicate: (day) =>
                    vm.startDate != null && isSameDay(day, vm.startDate) ||
                    vm.endDate != null && isSameDay(day, vm.endDate),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final isHoliday = holidayVm.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;
                    final isRequested = (isGrayed == false) && vm.isRequestedDate(day);

                    if (vm.isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed ? Colors.grey.withValues(alpha: 0.3) : AppColors.slate,
                        textColor: isGrayed ? AppColors.textMuted : Colors.white,
                        isRequested: isRequested,
                      );
                    }

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
                    final isHoliday = holidayVm.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;
                    final isRequested = (isGrayed == false) && vm.isRequestedDate(day);

                    if (vm.isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed ? Colors.grey.withValues(alpha: 0.3) : AppColors.slate,
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
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() => _focusedDay = focusedDay);
                  vm.selectDay(selectedDay, isHoliday: holidayVm.isHoliday);
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (vm.startDate != null)
                    Text(
                      vm.endDate == null
                          ? '${_formatDate(vm.startDate!)} 선택됨 · 종료일을 눌러주세요'
                          : '${_formatDate(vm.startDate!)} — ${_formatDate(vm.endDate!)}  (사용 가능 ${vm.usableDays(isHoliday: holidayVm.isHoliday)}일)',
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${info?.remainingLeaveDays ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.slate),
                        ),
                        TextSpan(
                          text: ' / ${info?.currTotalLeaveDays ?? 0} 일',
                          style: const TextStyle(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            value: vm.selectedLeaveType,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                            items: LeaveType.values.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              final willShowReason = ![LeaveType.full, LeaveType.amHalf, LeaveType.pmHalf].contains(value);
                              vm.selectLeaveType(value);
                              if (willShowReason) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _scrollController.animateTo(
                                    _scrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
                          color: AppColors.divider.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '${vm.useDaysText} 일',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (vm.needsReason) ...[
              const SizedBox(height: 16),
              const Text('사유', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '휴가 사유를 입력해주세요',
                  hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6)),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.divider.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Text('결재자', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    info != null ? '${info.approverName} ${info.approverPosition}  ' : '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            if (vm.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(vm.errorMessage!, style: const TextStyle(color: AppColors.coral, fontSize: 13)),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isSubmitting ? null : _handleSubmit,
                child: vm.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
