import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../profile/viewmodel/profile_viewmodel.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_drawer.dart';
import '../../../../widgets/confirm_dialog.dart';
import '../../../../widgets/leave_status_badge.dart';
import '../../common/model/dto/leave_request_record_dto.dart';
import '../../common/model/enum/leave_state.dart';
import '../../common/model/api_client/leave_request_common_api_client.dart';
import '../../common/model/util/leave_date_format.dart';
import '../model/api_client/leave_request_list_api_client.dart';
import '../viewmodel/leave_request_list_viewmodel.dart';

class AllLeaveRequestsScreen extends StatelessWidget {
  final String? status;
  final String? filter;

  const AllLeaveRequestsScreen({super.key, this.status, this.filter});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaveRequestListViewModel(
        LeaveRequestListApiClient(ApiClient()),
        LeaveRequestCommonApiClient(ApiClient()),
      )..init(initialStatus: status, initialShowMyOnly: filter == 'my'),
      child: const _AllLeaveRequestsView(),
    );
  }
}

class _AllLeaveRequestsView extends StatefulWidget {
  const _AllLeaveRequestsView();

  @override
  State<_AllLeaveRequestsView> createState() => _AllLeaveRequestsViewState();
}

class _AllLeaveRequestsViewState extends State<_AllLeaveRequestsView> {
  Future<void> _confirmCancel(LeaveRequestRecordDto item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '신청 취소',
      content: Text(
        '${item.startDate} — ${item.endDate} (${item.useDays}일)\n신청을 취소하시겠습니까?',
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      cancelLabel: '아니오',
      confirmLabel: '취소하기',
      confirmColor: AppColors.coral,
    );

    if (confirmed == true && mounted) {
      final success = await context.read<LeaveRequestListViewModel>().cancel(item.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '신청이 취소되었습니다.' : '취소 처리에 실패했습니다.')),
      );
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final vm = context.read<LeaveRequestListViewModel>();
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: vm.dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.slate),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      await vm.setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaveRequestListViewModel>();
    final userEmployeeNumber = context.watch<ProfileViewModel>().employeeInfo?.employeeNumber;

    final List<Map<String, String?>> statusOptions = [
      {'label': '전체', 'value': null},
      ...LeaveState.values.map((state) => {'label': state.label, 'value': state.code}),
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
                    width: MediaQuery.of(context).size.width * 0.2,
                    child: DropdownButton<String?>(
                      value: vm.statusFilter,
                      items: statusOptions
                          .map((option) => DropdownMenuItem<String?>(value: option['value'], child: Text(option['label']!)))
                          .toList(),
                      onChanged: (value) => vm.setStatusFilter(value),
                      underline: Container(height: 1, color: Colors.grey),
                      isExpanded: true,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => vm.toggleMode(),
                        label: Text(vm.showMyRequestsOnly ? '내 신청' : '전체', style: const TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          minimumSize: const Size(70, 36),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _pickDateRange(context),
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: const Text('기간 선택', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(100, 36),
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
                  Text('${formatIsoDate(vm.dateRange!.start)} — ${formatIsoDate(vm.dateRange!.end)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => vm.setDateRange(null),
                    child: const Text('지우기', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.slate))
                : vm.items.isEmpty
                    ? const Center(child: Text('조회된 내역이 없습니다.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: vm.items.length,
                        itemBuilder: (context, index) {
                          final item = vm.items[index];
                          final isProcessing = vm.processingIds.contains(item.requestId);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${item.employeeName} ${item.position}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    Text(item.department, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    LeaveStatusBadge(status: item.status),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    const SizedBox(height: 10),
                                    Text('${item.startDate} — ${item.endDate}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 12),
                                    Text('(${item.useDays}일)', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                    const SizedBox(width: 70),
                                    if (vm.isCancelable(item, userEmployeeNumber)) ...[
                                      const SizedBox(height: 20),
                                      const Divider(height: 1, color: AppColors.divider),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: isProcessing ? null : () => _confirmCancel(item),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: isProcessing
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
                                                )
                                              : const Text(
                                                  '신청 취소',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textMuted,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: AppColors.textMuted,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
