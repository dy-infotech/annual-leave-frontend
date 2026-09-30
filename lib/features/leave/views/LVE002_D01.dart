// LVE002_D01: 휴가 신청 상세 화면 (LVE002_M02/M03, LVE003_M01에서 진입)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/leave/models/leave_request_models.dart';
import 'package:annual_leave_frontend/features/leave/repositories/leave_repository.dart';
import 'package:annual_leave_frontend/features/leave/view_models/LVE002_D01_view_model.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import '../widgets/leave_status_badge.dart';

class LeaveRequestDetailScreen extends StatelessWidget {
  final int requestId;

  /// 미지정 시 실제 API를 호출한다. 테스트에서 페이크를 주입한다.
  final LeaveRepository? repository;

  const LeaveRequestDetailScreen(
      {super.key, required this.requestId, this.repository});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaveRequestDetailViewModel(
        requestId: requestId,
        repository: repository,
      )..load(),
      child: const _LeaveRequestDetailView(),
    );
  }
}

class _LeaveRequestDetailView extends StatelessWidget {
  const _LeaveRequestDetailView();

  static const Map<String, String> _leaveTypeMap = {
    'FULL': '연차',
    'AM_HALF': '반차(오전)',
    'PM_HALF': '반차(오후)',
    'ALTERNATIVE': '대체 휴가',
    'PARENTAL': '출산 휴가',
    'FAMILY': '가족 돌봄 휴가',
    'OTHER': '기타',
  };

  String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    return DateFormat('yyyy.MM.dd').format(DateTime.parse(raw));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaveRequestDetailViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('휴가 신청 상세 정보')),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.slate))
          : vm.errorMessage != null
              ? Center(
                  child: Text(vm.errorMessage!,
                      style: const TextStyle(color: AppColors.coral)))
              : _buildContent(vm.detail!),
    );
  }

  Widget _buildContent(LeaveRequestDetail d) {
    final leaveTypeNm = _leaveTypeMap[d.leaveType] ?? d.leaveType;
    final hasApprover = d.approverName != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // 1. 휴가자
        _sectionTitle('휴가자'),
        _card([
          _row('사번', d.employeeNumber),
          _row('이름', '${d.employeeName} ${d.position}'),
          _row('부서', d.department),
          _row('소속팀', d.team),
        ]),
        const SizedBox(height: 20),
        // 2. 신청 내역
        _sectionTitle('신청 내역'),
        _card([
          _row('휴가 종류', leaveTypeNm),
          _row('휴가 기간',
              '${_formatDate(d.startDate)} ~ ${_formatDate(d.endDate)}'),
          _row('사용 연차', '${d.useDays}일'),
          // 사유는 권한 있을 때(null 아님)만 표시
          // if (d.leaveReason != null) _row('사유', d.leaveReason!),
          // 사유 표시 (권한 있을때만 내용 표시)
          _row(
              '신청 사유',
              (d.leaveReason == null ||
                      d.leaveReason.toString() == 'null' ||
                      d.leaveReason.toString().isEmpty)
                  ? '-'
                  : d.leaveReason!),
          _row(
              '신청일',
              d.createdAt != null
                  ? DateFormat('yyyy.MM.dd')
                      .format(DateTime.parse(d.createdAt.toString()))
                  : '-'),
          // 상태는 배지로
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                    width: 80,
                    child: Text('상태',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600))),
                LeaveStatusBadge(status: d.status),
              ],
            ),
          ),
        ]),

        const SizedBox(height: 20),

        // 3. 결재 내역
        _sectionTitle('결재 내역'),
        _card(
          hasApprover
              ? [
                  _row('사번', d.approverNumber ?? '-'),
                  _row('이름', '${d.approverName} ${d.approverPosition ?? ''}'),
                  _row('부서', d.approverDepartment ?? '-'),
                  _row('소속팀', d.team ?? '-'),
                  _row(
                      '결재일',
                      (d.managedAt == null || d.managedAt.toString() == 'null')
                          ? '-'
                          : DateFormat('yyyy.MM.dd')
                              .format(DateTime.parse(d.managedAt.toString()))),
                  if (d.status == 'REJECTED')
                    _row(
                        '반려 사유',
                        (d.rejectReason == null || d.rejectReason!.isEmpty)
                            ? '-'
                            : d.rejectReason!),
                ]
              : [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('아직 승인되지 않은 요청입니다.',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textMuted)),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
          ],
        ),
      );
}
