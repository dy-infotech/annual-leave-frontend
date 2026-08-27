// LVE003_M01: 결재 대기 목록 화면
import 'package:annual_leave_frontend/app/app.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE003_M01_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

import 'LVE002_D01.dart';

class PendingApprovalScreen extends StatelessWidget {
  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final LeaveRepository? repository;

  const PendingApprovalScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PendingApprovalViewModel(repository: repository)..fetch(),
      child: const _PendingApprovalView(),
    );
  }
}

class _PendingApprovalView extends StatefulWidget {
  const _PendingApprovalView();

  @override
  State<_PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<_PendingApprovalView>
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
    context.read<PendingApprovalViewModel>().fetch();
  }

  // [하단 고정 버튼 전용] 단건 승인 다이얼로그
  Future<void> _confirmApproveSingle(PendingApprovalViewModel vm) async {
    final req = vm.selectedRequest;
    if (req == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title:
            const Text('승인 확인', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${req.employeeName}님의 휴가 신청\n(${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.endDate))}, ${req.useDays}일)을\n승인하시겠습니까?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('승인',
                style: TextStyle(
                    color: AppColors.sage, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await vm.approve(req.requestId);
      messenger.showSnackBar(SnackBar(
          content: Text(ok ? '승인 처리되었습니다.' : '승인 처리에 실패했습니다.')));
    }
  }

  // [하단 고정 버튼 전용] 단건 반려 사유 입력 다이얼로그
  Future<void> _showRejectDialogSingle(PendingApprovalViewModel vm) async {
    final req = vm.selectedRequest;
    if (req == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title:
            const Text('반려 확인', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${req.employeeName}님의 휴가 신청\n(${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.endDate))}, ${req.useDays}일)을\n반려하시겠습니까?',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: '반려 사유 (선택 입력)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('취소', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('반려',
                style: TextStyle(
                    color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await vm.reject(req.requestId, controller.text.trim());
      messenger.showSnackBar(SnackBar(
          content: Text(ok ? '반려 처리되었습니다.' : '반려 처리에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PendingApprovalViewModel>();
    bool showBottomBar =
        !vm.isLoading && vm.errorMessage == null && vm.requests.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('결재 대기 목록')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(onRefresh: vm.fetch, child: _buildBody(vm)),
      bottomNavigationBar: showBottomBar ? _buildBottomAppBar(vm) : null,
    );
  }

  // 화면 최하단 고정 승인/반려 버튼
  Widget _buildBottomAppBar(PendingApprovalViewModel vm) {
    bool hasSelection = vm.hasSelection;
    bool isProcessing = vm.isProcessing;
    bool canPress = hasSelection && !isProcessing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canPress ? () => _showRejectDialogSingle(vm) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44), // 스크롤 캡처와 비슷한 컴팩트한 높이
                  foregroundColor: const Color(
                      0xFFD67361), // 기존 AppColors.coral 혹은 스크롤 속 주황/코랄 색상
                  side: BorderSide(
                    color: canPress
                        ? const Color(0xFFD67361)
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('반려',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canPress ? () => _confirmApproveSingle(vm) : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: canPress
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade300, // 스크롤 속 짙은 네이비 색상
                  foregroundColor:
                      canPress ? Colors.white : Colors.grey.shade500,
                  elevation: 0,
                  shape: const StadiumBorder(), // 양 끝이 완전히 둥근 스타디움 모양 버튼
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('승인',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PendingApprovalViewModel vm) {
    if (vm.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.slate));
    }
    if (vm.errorMessage != null) {
      return Center(
          child: Text(vm.errorMessage!,
              style: const TextStyle(color: AppColors.textMuted)));
    }
    if (vm.requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(
              child: Text('대기 중인 휴가 신청이 없습니다.',
                  style: TextStyle(color: AppColors.textMuted))),
        ],
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor:
              WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.3)),
          thickness: const WidgetStatePropertyAll(5),
          radius: const Radius.circular(8),
        ),
      ),
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        child: ListView.builder(
          controller: _scrollController,
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 100),
          itemCount: vm.requests.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템 자리에 상단 우측 끝 "조회건수" 라벨 배치
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${vm.requests.length}건',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            final req = vm.requests[index - 1];
            final bool isSelected = vm.selectedRequestId == req.requestId;
            final leaveTypeNm = LeaveType.getLabel(req.leaveType);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? AppColors.slate : AppColors.divider,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  vm.select(req.requestId);
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 13, right: 15, top: 10, bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 좌측: 불필요한 패딩이 없는 완벽한 커스텀 원형 라디오 버튼
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 1), // 첫 줄 글자 높이와 눈높이를 맞추기 위한 마진
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2C3E50)
                                  : Colors.grey.shade400,
                              width: isSelected
                                  ? 5.5
                                  : 1.5, // 선택되면 두꺼워지면서 안쪽이 채워지는 효과
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10), // 라디오 원과 텍스트 사이 간격 확보

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 첫 번째 줄: 이름·직급·부서 / 우측 끝에 상세 버튼
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${req.employeeName} ${req.position}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        req.team,
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 상세 버튼 (라디오 선택과 분리된 별도 탭 영역)
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            LeaveRequestDetailScreen(
                                                requestId: req.requestId),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '상세',
                                          style: TextStyle(
                                            color: AppColors.slate,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Icon(Icons.chevron_right,
                                            size: 16, color: AppColors.slate),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),

                            // 두 번째 줄: 휴가 일자 정보
                            Row(
                              children: [
                                Text(
                                  '${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.startDate))} ~ ${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.endDate))}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 4),
                                Text('(${req.useDays}일) [$leaveTypeNm]',
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),

                            // 세 번째 줄: 신청일 (신청 목록 화면과 동일하게 하단 배치)
                            Text(
                              '신청일 : ${DateFormat('yyyy.MM.dd').format(DateTime.parse(req.createdAt))}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
