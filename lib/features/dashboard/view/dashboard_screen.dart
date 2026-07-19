import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/api_client.dart';
import '../../../main.dart' show routeObserver;
import '../../../theme/app_theme.dart';
import '../../../widgets/app_drawer.dart';
import '../../leave_request/list/view/all_leave_requests_screen.dart';
import '../model/dto/dashboard_dto.dart';
import '../model/api_client/dashboard_api_client.dart';
import '../viewmodel/dashboard_viewmodel.dart';

// 이제 이 화면에서만 DashboardViewModel을 구독하므로(my_info_screen은 Profile
// 데이터만으로 대체됨), 전역이 아니라 화면 전용(scoped) Provider로 내림.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel(DashboardApiClient(ApiClient())),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardViewModel>().fetchDashboard();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 이 화면으로의 라우트 변화를 구독 (push/pop 감지를 위해 필요)
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // 다른 화면(승인 처리, 휴가 신청 등)에 갔다가
  // 이 대시보드 화면으로 다시 돌아왔을 때 자동으로 호출됨
  @override
  void didPopNext() {
    context.read<DashboardViewModel>().fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('대시보드'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const _MenuGlyph(),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => context.read<DashboardViewModel>().fetchDashboard(),
        child: _buildBody(dashboard),
      ),
    );
  }

  Widget _buildBody(DashboardViewModel dashboard) {
    if (dashboard.isLoading && dashboard.data == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.slate));
    }
    if (dashboard.errorMessage != null && dashboard.data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dashboard.errorMessage!, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.read<DashboardViewModel>().fetchDashboard(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    final data = dashboard.data;
    if (data == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const _SectionLabel('내 휴가 정보'),
        _StatRow(items: [
          _StatItem('배정', data.myLeaveInfo.totalLeaveDays, AppColors.slate),
          _StatItem('사용', data.myLeaveInfo.usedLeaveDays, AppColors.amber),
          _StatItem('잔여', data.myLeaveInfo.remainingLeaveDays, AppColors.sage),
        ]),
        const SizedBox(height: 28),

        const _SectionLabel('내 휴가 신청 현황'),
        _buildRequestSummaryRow(context, data.myRequestSummary, filter: 'my'),
        if (data.allEmployeeRequestSummary != null) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const _SectionLabel('전직원 휴가 신청 현황'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.slate.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('관리자',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
              ),
            ],
          ),
          _buildRequestSummaryRow(context, data.allEmployeeRequestSummary!, filter: 'all'),
        ],
      ],
    );
  }

  // "내 휴가 신청 현황"과 "전직원 휴가 신청 현황"이 대기/승인/반려 3개 항목+
  // 각각의 필터링된 목록으로 이동하는 탭 동작까지 완전히 동일한 구조였어서,
  // filter('my'/'all')만 다르게 받아 하나로 합침.
  Widget _buildRequestSummaryRow(BuildContext context, LeaveRequestSummaryDto summary, {required String filter}) {
    _StatItem statItem(String label, int count, Color color, String status) {
      return _StatItem(
        label,
        count.toDouble(),
        color,
        isCount: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AllLeaveRequestsScreen(status: status, filter: filter)),
          );
        },
      );
    }

    return _StatRow(items: [
      statItem('대기', summary.pendingCount, AppColors.amber, 'PENDING'),
      statItem('승인', summary.approvedCount, AppColors.sage, 'APPROVED'),
      statItem('반려', summary.rejectedCount, AppColors.coral, 'REJECTED'),
    ]);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isCount;
  final VoidCallback? onTap;

  const _StatItem(
    this.label,
    this.value,
    this.color, {
    this.isCount = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        Text(label),
        Text(value.toString(), style: TextStyle(color: color)),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

class _StatRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: items.map((item) {
          final displayValue = item.isCount
              ? item.value.toInt().toString()
              : item.value.toStringAsFixed(item.value % 1 == 0 ? 0 : 1);

          return Expanded(
            child: GestureDetector(
              onTap: item.onTap,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  Text(displayValue,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(item.label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 20, height: 2, color: AppColors.textPrimary),
          Container(width: 14, height: 2, color: AppColors.textPrimary),
          Container(width: 20, height: 2, color: AppColors.textPrimary),
        ],
      ),
    );
  }
}
