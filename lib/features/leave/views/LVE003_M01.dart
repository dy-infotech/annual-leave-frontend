// LVE003_M01: 결재 대기 목록 화면
import 'package:annual_leave_frontend/app/app.dart';
import 'package:annual_leave_frontend/features/leave/models/enums/LeaveType.dart';
import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

import 'LVE002_D01.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with RouteAware {
  List<PendingLeaveRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _processingIds = {};
  final ScrollController _scrollController = ScrollController();

  // 단건 선택을 위한 상태 변수 (아무것도 선택되지 않았을 때는 null)
  int? _selectedRequestId;

  @override
  void initState() {
    super.initState();
    _fetchPendingList();
  }

  Future<void> _fetchPendingList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedRequestId = null; // 목록 새로고침 시 선택 상태 초기화
    });

    try {
      final response =
          await ApiClient().dio.get('/api/admin/leave-requests/pending');
      final list = (response.data as List)
          .map((json) => PendingLeaveRequest.fromJson(json))
          .toList();
      setState(() => _requests = list);
    } catch (e) {
      setState(() => _errorMessage = '목록을 불러오지 못했습니다.');
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
    _fetchPendingList();
  }

  // 현재 라디오 버튼으로 선택된 객체를 찾는 헬퍼 메서드
  PendingLeaveRequest? _getSelectedRequest() {
    if (_selectedRequestId == null) return null;
    return _requests.firstWhere((req) => req.requestId == _selectedRequestId);
  }

  // [하단 고정 버튼 전용] 단건 승인 다이얼로그
  Future<void> _confirmApproveSingle() async {
    final req = _getSelectedRequest();
    if (req == null) return;

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
      await _approve(req.requestId);
    }
  }

  Future<void> _approve(int requestId) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient()
          .dio
          .post('/api/admin/leave-requests/$requestId/approve');
      _showSnackBar('승인 처리되었습니다.');
      await _fetchPendingList();
    } catch (e) {
      _showSnackBar('승인 처리에 실패했습니다.');
    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  // [하단 고정 버튼 전용] 단건 반려 사유 입력 다이얼로그
  Future<void> _showRejectDialogSingle() async {
    final req = _getSelectedRequest();
    if (req == null) return;

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
      await _reject(req.requestId, controller.text.trim());
    }
  }

  Future<void> _reject(int requestId, String reason) async {
    setState(() => _processingIds.add(requestId));
    try {
      await ApiClient().dio.post(
        '/api/admin/leave-requests/$requestId/reject',
        data: {'rejectReason': reason.isEmpty ? null : reason},
      );
      _showSnackBar('반려 처리되었습니다.');
      await _fetchPendingList();
    } catch (e) {
      _showSnackBar('반려 처리에 실패했습니다.');
    } finally {
      setState(() => _processingIds.remove(requestId));
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showBottomBar =
        !_isLoading && _errorMessage == null && _requests.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('결재 대기 목록')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(onRefresh: _fetchPendingList, child: _buildBody()),
      bottomNavigationBar: showBottomBar ? _buildBottomAppBar() : null,
    );
  }

  // 화면 최하단 고정 승인/반려 버튼
  Widget _buildBottomAppBar() {
    bool hasSelection = _selectedRequestId != null;
    bool isProcessing = _processingIds.isNotEmpty;
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
                onPressed: canPress ? _showRejectDialogSingle : null,
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
                onPressed: canPress ? _confirmApproveSingle : null,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.slate));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: AppColors.textMuted)));
    }
    if (_requests.isEmpty) {
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
          itemCount: _requests.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템 자리에 상단 우측 끝 "조회건수" 라벨 배치
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_requests.length}건',
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
            final req = _requests[index - 1];
            final bool isSelected = _selectedRequestId == req.requestId;
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
                  setState(() => _selectedRequestId = req.requestId);
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
