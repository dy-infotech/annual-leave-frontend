import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_drawer.dart';
import '../../../../widgets/confirm_dialog.dart';
import '../model/dto/pending_leave_request_dto.dart';
import '../model/api_client/leave_approval_api_client.dart';
import '../viewmodel/leave_approval_viewmodel.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaveApprovalViewModel(LeaveApprovalApiClient(ApiClient()))..fetchPendingList(),
      child: const _PendingApprovalView(),
    );
  }
}

class _PendingApprovalView extends StatefulWidget {
  const _PendingApprovalView();

  @override
  State<_PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<_PendingApprovalView> {
  Future<void> _confirmApprove(PendingLeaveRequestDto req) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '승인 확인',
      content: Text(
        '${req.employeeName}님의 휴가 신청\n(${req.startDate} — ${req.endDate}, ${req.useDays}일)을\n승인하시겠습니까?',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      confirmLabel: '승인',
      confirmColor: AppColors.sage,
    );

    if (confirmed == true && mounted) {
      final success = await context.read<LeaveApprovalViewModel>().approve(req.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '승인 처리되었습니다.' : '승인 처리에 실패했습니다.')),
      );
    }
  }

  Future<void> _showRejectDialog(PendingLeaveRequestDto req) async {
    final controller = TextEditingController();
    final confirmed = await showConfirmDialog(
      context,
      title: '반려 확인',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${req.employeeName}님의 휴가 신청\n(${req.startDate} — ${req.endDate}, ${req.useDays}일)을\n반려하시겠습니까?',
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
      confirmLabel: '반려',
      confirmColor: AppColors.coral,
    );

    if (confirmed == true && mounted) {
      final success = await context.read<LeaveApprovalViewModel>().reject(req.requestId, controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '반려 처리되었습니다.' : '반려 처리에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaveApprovalViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('승인 대기 목록')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => context.read<LeaveApprovalViewModel>().fetchPendingList(),
        child: _buildBody(vm),
      ),
    );
  }

  Widget _buildBody(LeaveApprovalViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.slate));
    }

    if (vm.errorMessage != null) {
      return Center(child: Text(vm.errorMessage!, style: const TextStyle(color: AppColors.textMuted)));
    }

    if (vm.requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('대기 중인 휴가 신청이 없습니다.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: vm.requests.length,
      itemBuilder: (context, index) {
        final req = vm.requests[index];
        final isProcessing = vm.processingIds.contains(req.requestId);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${req.employeeName} ${req.position} (${req.employeeNumber})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                  ),
                  Text(req.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${req.startDate} — ${req.endDate}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Text('(${req.useDays}일)', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isProcessing ? null : () => _confirmApprove(req),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('승인'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isProcessing ? null : () => _showRejectDialog(req),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        foregroundColor: AppColors.coral,
                        side: const BorderSide(color: AppColors.coral, width: 1.3),
                      ),
                      child: const Text('반려'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
