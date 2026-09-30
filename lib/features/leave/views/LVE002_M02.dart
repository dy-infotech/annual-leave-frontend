// LVE002_M02: 전직원 휴가 신청 목록 화면
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_M02_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import '../widgets/leave_status_badge.dart';
import '../widgets/date_range_dialog.dart';
import 'package:annual_leave_frontend/app/app.dart';
import 'package:intl/intl.dart';

import 'LVE002_D01.dart';

class AllLeaveRequestsScreen extends StatelessWidget {
  final String? status;
  final String? filter;

  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final LeaveRepository? repository;

  const AllLeaveRequestsScreen(
      {super.key, this.status, this.filter, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AllLeaveRequestsViewModel(
        initialStatus: status,
        initialFilter: filter,
        repository: repository,
      )..load(),
      child: const _AllLeaveRequestsView(),
    );
  }
}

class _AllLeaveRequestsView extends StatefulWidget {
  const _AllLeaveRequestsView();

  @override
  State<_AllLeaveRequestsView> createState() => _AllLeaveRequestsViewState();
}

class _AllLeaveRequestsViewState extends State<_AllLeaveRequestsView>
    with RouteAware {
  final ScrollController _scrollController = ScrollController();

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
    context.read<AllLeaveRequestsViewModel>().fetch();
  }

  Future<void> _confirmCancel(
      AllLeaveRequestsViewModel vm, LeaveRequestListItem item) async {
    final messenger = ScaffoldMessenger.of(context);
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
      final ok = await vm.cancel(item.requestId);
      messenger.showSnackBar(SnackBar(
          content: Text(ok ? '신청이 취소되었습니다.' : '취소 처리에 실패했습니다.')));
    }
  }

  Future<void> _pickDateRange(AllLeaveRequestsViewModel vm) async {
    final year = DateTime.now().year;
    final initial = vm.dateRange ??
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
    if (picked != null && mounted) {
      vm.setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AllLeaveRequestsViewModel>();
    final userEmployeeNumber =
        context.watch<AuthSession>().employeeInfo?.employeeNumber;
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
                    width: MediaQuery.of(context).size.width * 0.23,
                    //height: 40, // 원하는 높이로 조절
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: vm.statusFilter,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black),
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Colors.grey),
                        alignment: Alignment.centerLeft,

                        // 💡 [핵심 추가] 아웃라인 테두리 왼쪽 위에 '팀' 라벨 텍스트를 강제 배치합니다.
                        decoration: InputDecoration(
                          labelText: '상태',
                          labelStyle:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                          isDense: true,

                          // 🔥 [높이 정렬 고정] 상하 패딩을 '등록 상태' 박스와 똑같은 '9.5'로 일치시켜
                          // 화면에서 두 콤보박스의 가로선 높이가 자석처럼 완벽한 일직선을 이루게 만듭니다.
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 9.5),

                          // 💡 테두리 곡률(Radius: 8) 및 색상 디자인 통일
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
                          vm.setFilter(newValue);
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
                  //const SizedBox(width: 5),
                  const Spacer(), // 드롭다운과 버튼 그룹 사이 넓은 공간 확보
                  Row(
                    children: [
                      // 라디오 버튼 목록
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: searchFilterList.map((item) {
                          final label = item['label']!;
                          return Padding(
                            // '전체' 글자와 '내 신청' 아이콘이 붙지 않도록 오른쪽에만 여백을 줍니다.
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: 0.8, // 라디오 원 크기 축소
                                  child: Radio<String>(
                                    value: label,
                                    groupValue: vm.buttonLabel,
                                    // 1. 아이콘 주변의 불필요한 기본 시각적 여백을 완전히 제거합니다.

                                    visualDensity: const VisualDensity(
                                      horizontal: VisualDensity.minimumDensity,
                                      vertical: VisualDensity.minimumDensity,
                                    ),
                                    // 2. 터치 영역 제한(48x48)을 풀어 글자와 완전히 밀착시킵니다.
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (value) {
                                      vm.setButtonLabel(value!);
                                    },
                                  ),
                                ),
                                // 3. 기본 여백이 사라졌으므로, 원하는 만큼만 미세하게 간격을 지정합니다.
                                const SizedBox(width: 1),
                                Text(label),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(width: 5), // 두 버튼 간격

                      ElevatedButton.icon(
                        onPressed: () {
                          _pickDateRange(vm);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text(
                          '기간',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          minimumSize: const Size(75, 40),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (vm.dateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                      '${AllLeaveRequestsViewModel.formatDate(vm.dateRange!.start)} - ${AllLeaveRequestsViewModel.formatDate(vm.dateRange!.end)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      vm.clearDateRange();
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
                // 실제 리스트 데이터인 items의 길이를 가져와 동적으로 건수를 표시 (조회건수)

                Text(
                  '${vm.items.length}건',
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
            child: vm.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.slate))
                : vm.items.isEmpty
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
                            itemCount: vm.items.length,
                            itemBuilder: (context, index) {
                              final item = vm.items[index];
                              final isProcessing =
                                  vm.isProcessing(item.requestId);
                              final leaveTypeNm =
                                  LeaveType.getLabel(item.leaveType);

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
                                                if (AllLeaveRequestsViewModel
                                                    .isCancelable(item,
                                                        userEmployeeNumber)) ...[
                                                  TextButton(
                                                    onPressed: isProcessing
                                                        ? null
                                                        : () => _confirmCancel(
                                                            vm, item),
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
