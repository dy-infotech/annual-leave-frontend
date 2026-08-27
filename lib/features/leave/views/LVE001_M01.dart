// LVE001_M01: 휴가 신청 화면
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveState.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/providers/auth_provider.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/repositories/public_holiday_repository.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE001_M01_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';

class LeaveRequestScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final LeaveRepository? repository;
  final PublicHolidayRepository? holidayRepository;

  const LeaveRequestScreen({super.key, this.repository, this.holidayRepository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LeaveRequestViewModel(
        authProvider: context.read<AuthProvider>(),
        repository: repository,
        holidayRepository: holidayRepository,
      )..load(),
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
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onDaySelected(
      LeaveRequestViewModel vm, DateTime selectedDay, DateTime focusedDay) {
    final rangeConfirmed = vm.selectDay(selectedDay, focusedDay);

    // 종료일(또는 반차 단일일) 확정 시 신청 중복 확인 -> 일수 초과 확인
    if (rangeConfirmed) {
      _onRangeConfirmed(vm);
    }
  }

  // 기간 확정 시 중복 확인 -> 초과 확인 순서로 안내
  Future<void> _onRangeConfirmed(LeaveRequestViewModel vm) async {
    // 중복이 있으면 그 안내만 띄우고 종료 (초과 안내는 생략)
    if (await _checkOverlapAndWarn(vm)) return;
    // 중복이 없으면 잔여 연차 초과 여부 확인
    await _checkRemainingAndWarn(vm);
  }

  Future<void> _handleSubmit(LeaveRequestViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);

    if (vm.startDate == null || vm.endDate == null) {
      vm.setError('날짜를 선택해주세요.');
      return;
    }

    if (vm.useDays <= 0) {
      vm.setError('사용 일수가 변경되지 않았습니다. 날짜를 다시 선택해 주세요.');
      return;
    }

    // 기존 대기/승인 신청과 기간이 겹치는지 확인
    if (await _checkOverlapAndWarn(vm, refresh: true)) {
      return; // 다이얼로그 닫히면 제출을 진행하지 않고 종료
    }

    // 잔여 연차 초과 여부 확인
    if (await _checkRemainingAndWarn(vm)) {
      return; // 초과 시 제출 중단
    }

    // 최종 확인 다이얼로그
    if (!await _confirmSubmit(vm)) {
      return;
    }

    final ok = await vm.submit();
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('휴가 신청이 완료되었습니다.')),
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  // 별의 왼쪽(오전) 또는 오른쪽(오후) 절반만 그리기
  Widget _buildHalfStar({
    required bool isLeft,
    Color color = Colors.yellow,
    double size = 32,
  }) {
    return ClipRect(
      clipper: _HalfClipper(isLeft: isLeft),
      child: Icon(Icons.star_rounded, size: size, color: color),
    );
  }

  Widget _buildDayCell({
    required int day,
    required Color? backgroundColor,
    required Color textColor,
    required String? amStatus, // 오전 상태 (null이면 없음)
    required String? pmStatus, // 오후 상태
    bool isToday = false,
  }) {
    final hasAm = amStatus != null;
    final hasPm = pmStatus != null;
    final isRequested = hasAm || hasPm;

    Widget buildStar() {
      // 온전한 별
      Widget fullStar(String? status) {
        if (status == LeaveState.approved.code) {
          // 승인: 깜빡이는 별
          return const _PulsingStar();
        } else if (status == LeaveState.pending.code) {
          // 대기: 노란색 별
          return const Icon(Icons.star_rounded, size: 32, color: Colors.yellow);
        } else {
          // 반려: 회색 별
          return Icon(Icons.star_rounded,
              size: 32, color: Colors.grey.withOpacity(0.4));
        }
      }

      // 반쪽 별
      Widget halfStar(bool isLeft, String? status) {
        if (status == LeaveState.approved.code) {
          return _PulsingStar(isHalf: true, isLeft: isLeft);
        } else if (status == LeaveState.pending.code) {
          return _buildHalfStar(isLeft: isLeft);
        } else {
          return _buildHalfStar(
              isLeft: isLeft, color: Colors.grey.withOpacity(0.4));
        }
      }

      if (hasAm && hasPm) {
        if (amStatus == pmStatus) {
          return fullStar(amStatus);
        } else {
          return Stack(children: [
            halfStar(true, amStatus),
            halfStar(false, pmStatus),
          ]);
        }
      } else if (hasAm) {
        return halfStar(true, amStatus);
      } else {
        return halfStar(false, pmStatus);
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
  Future<bool> _checkOverlapAndWarn(LeaveRequestViewModel vm,
      {bool refresh = false}) async {
    if (!await vm.hasOverlapForSelection(refresh: refresh)) {
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
          '해당 기간에 이미 대기 중이거나 승인된 휴가 신청이 있습니다.\n기간을 다시 확인해 주세요.',
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

  // 선택한 기간의 사용 일수가 잔여 연차를 초과하는지 확인하고, 초과 시 안내 다이얼로그 표시
  // 초과하면 true 반환 (제출 흐름에서 중단용)
  Future<bool> _checkRemainingAndWarn(LeaveRequestViewModel vm) async {
    // 사용 일수가 잔여 연차 이하이면 통과
    if (!vm.exceedsRemaining()) return false;

    if (!mounted) return true;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('잔여 연차 부족 안내',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          '선택한 기간의 사용 일수(${vm.useDays}일)가 '
          '잔여 연차(${vm.remainingLeaveDays}일)를 초과합니다.\n기간을 다시 확인해 주세요.',
          style: const TextStyle(fontSize: 14, height: 1.5),
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
  Future<bool> _confirmSubmit(LeaveRequestViewModel vm) async {
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
            _confirmRow('휴가 종류', vm.selectedLeaveType.label),
            const SizedBox(height: 6),
            _confirmRow(
              '기간',
              vm.endDate == null || vm.startDate == vm.endDate
                  ? _formatDate(vm.startDate!)
                  : '${_formatDate(vm.startDate!)} ~ ${_formatDate(vm.endDate!)}',
            ),
            const SizedBox(height: 6),
            _confirmRow('사용 연차', '${vm.useDaysText}일'),
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
    final vm = context.watch<LeaveRequestViewModel>();
    final authProvider = context.watch<AuthProvider>().employeeInfo;

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
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.slate),
                            ),
                            // 결재자 Container 내부 child 구역 (기존 authProvider 변수명 그대로 유지)
// 결재자 Container 내부 child 구역 (기존 변수명 100% 동일하게 유지)
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (authProvider != null) ...[
                                  // 1번째 행: 이름과 직급 (기존 변수 그대로)
                                  Text(
                                    '${authProvider.name} ${authProvider.position}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary),
                                  ),

                                  const SizedBox(height: 4), // 위아래 간격

                                  // 2번째 행: 부서 정보 (기존 변수 그대로, 아랫줄로 이동)
                                  Text(
                                    authProvider.team,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 결재자
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('결재자',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Stack(
                            fit: StackFit.passthrough,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (authProvider != null) ...[
                                      // 1번째 행: 이름과 직급 (기존 변수명 100% 유지, 크고 진하게)
                                      Text(
                                        '${authProvider.approverName} ${authProvider.approverPosition}',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary),
                                      ),

                                      // 행 사이의 깔끔한 세로 간격 확보
                                      const SizedBox(height: 4),

                                      // 2번째 행: 부서 정보 (아랫줄로 안전하게 이동, 작고 연하게)
                                      Text(
                                        authProvider.team,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1, // 긴 부서 이름 깨짐 방지 안전장치
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w400),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // 우측 상단 호버 툴팁 (기존 코드 그대로 유지)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.help,
                                  child: Tooltip(
                                    message:
                                        'PL은 0xFFC9A66B를 원했으나, 망막 보호를 위해 0xFF2B3A4A를 적용함',
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
                            ], // 대괄호 마무리 구역
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
                  child: vm.startDate != null
                      ? Text(
                          vm.endDate == null
                              ? '${_formatDate(vm.startDate!)} 선택됨 · 종료일을 눌러주세요'
                              : '${_formatDate(vm.startDate!)} — ${_formatDate(vm.endDate!)}',
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
                rowHeight: 42,
                daysOfWeekHeight: 22,
                firstDay: DateTime(DateTime.now().year - 1, 1, 1),
                lastDay: DateTime(DateTime.now().year, 12, 31),
                focusedDay: vm.focusedDay,
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
                    vm.startDate != null && isSameDay(day, vm.startDate) ||
                    vm.endDate != null && isSameDay(day, vm.endDate),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final isHoliday = vm.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;

                    // 오전/오후 휴가 상태 조회
                    final half = (isGrayed == false)
                        ? vm.halfDayStatus(day)
                        : (amStatus: null, pmStatus: null);

                    if (vm.isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed
                            ? Colors.grey.withOpacity(0.3)
                            : AppColors.slate,
                        textColor:
                            isGrayed ? AppColors.textMuted : Colors.white,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                      );
                    }

                    if (isHoliday ||
                        half.amStatus != null ||
                        half.pmStatus != null) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: null,
                        textColor:
                            isHoliday ? AppColors.coral : AppColors.textPrimary,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                      );
                    }

                    return null;
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final isHoliday = vm.isHoliday(day);
                    final isWeekend = day.weekday == DateTime.saturday ||
                        day.weekday == DateTime.sunday;
                    final isGrayed = isWeekend || isHoliday;

                    // 오전/오후 휴가 상태 조회
                    final half = (isGrayed == false)
                        ? vm.halfDayStatus(day)
                        : (amStatus: null, pmStatus: null);

                    // 선택된 범위 안의 오늘: 슬레이트 배경 유지 + 빨간 밑줄
                    if (vm.isInRange(day)) {
                      return _buildDayCell(
                        day: day.day,
                        backgroundColor: isGrayed
                            ? Colors.grey.withOpacity(0.3)
                            : AppColors.slate,
                        textColor:
                            isGrayed ? AppColors.textMuted : Colors.white,
                        amStatus: half.amStatus,
                        pmStatus: half.pmStatus,
                        isToday: true,
                      );
                    }

                    // 범위 밖의 오늘: 원형 배경 없이 숫자 + 빨간 밑줄
                    return _buildDayCell(
                      day: day.day,
                      backgroundColor: null,
                      textColor:
                          isGrayed ? AppColors.coral : AppColors.textPrimary,
                      amStatus: half.amStatus,
                      pmStatus: half.pmStatus,
                      isToday: true,
                    );
                  },
                ),
                onDaySelected: (selectedDay, focusedDay) =>
                    _onDaySelected(vm, selectedDay, focusedDay),
                onPageChanged: (focusedDay) => vm.focusedDay = focusedDay,
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
                            value: vm.selectedLeaveType,
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
                                final willShowReason = vm.setLeaveType(value);

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
                          '${vm.useDaysText} 일',
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
            if (vm.needsReason) ...[
              const Text('사유',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              TextField(
                controller: vm.reasonController,
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

            if (vm.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                vm.errorMessage!,
                style: const TextStyle(color: AppColors.coral, fontSize: 13),
              ),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isSubmitting ? null : () => _handleSubmit(vm),
                child: vm.isSubmitting
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
        ? Rect.fromLTRB(0, 0, size.width / 2, size.height) // 왼쪽 절반
        : Rect.fromLTRB(size.width / 2, 0, size.width, size.height); // 오른쪽 절반
  }

  @override
  bool shouldReclip(_HalfClipper old) => old.isLeft != isLeft;
}

// 대기 건: 글로우가 깜빡이는 별 (온전한 별 or 반쪽 별)
class _PulsingStar extends StatefulWidget {
  final bool isHalf; // 반쪽 여부 (반차)
  final bool isLeft; // 반쪽일 때 왼쪽(오전) / 오른쪽(오후)
  final double size;

  const _PulsingStar({
    this.isHalf = false,
    this.isLeft = true,
    this.size = 32,
  });

  @override
  State<_PulsingStar> createState() => _PulsingStarState();
}

class _PulsingStarState extends State<_PulsingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // 깜빡임 속도
    )..repeat(reverse: true);

    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _opacity = Tween(begin: 1.0, end: 0.45).animate(curve);
    _scale = Tween(begin: 0.8, end: 1.0).animate(curve);
    _glow = Tween(begin: 2.0, end: 12.0).animate(curve); // 글로우 세기
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final star = Icon(
          Icons.star_rounded,
          size: widget.size,
          color: Colors.yellow,
          shadows: [
            Shadow(
              color: const Color(0xFFFF6F00), // 글로우 컬러
              blurRadius: _glow.value,
            ),
            Shadow(
              color: const Color(0xFFFF9800), // 글로우 컬러
              blurRadius: _glow.value / 2,
            ),
          ],
        );

        final content = widget.isHalf
            ? ClipRect(
                clipper: _HalfClipper(isLeft: widget.isLeft),
                child: star,
              )
            : star;

        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: content,
          ),
        );
      },
    );
  }
}
