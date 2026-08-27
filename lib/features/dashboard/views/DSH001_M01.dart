// DSH001_M01: 대시보드 화면
import 'package:annual_leave_frontend/features/leave/views/LVE002_M03.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/app/app.dart' show routeObserver;
import 'package:annual_leave_frontend/providers/dashboard_provider.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:annual_leave_frontend/core/widgets/app_drawer.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE002_M02.dart';
import 'package:annual_leave_frontend/features/leave/views/LVE003_M01.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  String? flagTest; // null = 전체

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().fetchDashboard();
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
    context.read<DashboardProvider>().fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();

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
        onRefresh: () => context.read<DashboardProvider>().fetchDashboard(),
        child: _buildBody(dashboard),
      ),
    );
  }

  Widget _buildBody(DashboardProvider dashboard) {
    if (dashboard.isLoading && dashboard.data == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.slate));
    }
    if (dashboard.errorMessage != null && dashboard.data == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(dashboard.errorMessage!,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  context.read<DashboardProvider>().fetchDashboard(),
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
        _StatRow(items: [
          _StatItem(
            '대기',
            data.myRequestSummary.pendingCount.toDouble(),
            AppColors.amber,
            isCount: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AllLeaveRequestsScreen(
                        status: 'PENDING', filter: 'my')),
              );
            },
          ),
          _StatItem(
            '승인',
            data.myRequestSummary.approvedCount.toDouble(),
            AppColors.sage,
            isCount: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AllLeaveRequestsScreen(
                        status: 'APPROVED', filter: 'my')),
              );
            },
          ),
          _StatItem(
            '반려',
            data.myRequestSummary.rejectedCount.toDouble(),
            AppColors.coral,
            isCount: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AllLeaveRequestsScreen(
                        status: 'REJECTED', filter: 'my')),
              );
            },
          ),
        ]),
        if (data.allEmployeeRequestSummary != null) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const _SectionLabel('전직원 휴가 신청 현황'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.slate.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('관리자',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate)),
              ),
            ],
          ),
          _StatRow(items: [
            _StatItem(
              '대기',
              data.allEmployeeRequestSummary!.pendingCount.toDouble(),
              AppColors.amber,
              isCount: true,
              onTap: () {
                Navigator.push(
                  context,
                  //MaterialPageRoute(builder: (context) => AllLeaveRequestsScreen(status: 'PENDING', filter: 'all')),
                  MaterialPageRoute(
                      builder: (context) => PendingApprovalScreen(
                          //status: 'PENDING', filter: 'all'
                          )),
                );
              },
            ),
            _StatItem(
              '승인',
              data.allEmployeeRequestSummary!.approvedCount.toDouble(),
              AppColors.sage,
              isCount: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AdminSearchLeaveRequestsScreen(
                          status: 'APPROVED', filter: 'admin_approved')),
                );
              },
            ),
            _StatItem(
              '반려',
              data.allEmployeeRequestSummary!.rejectedCount.toDouble(),
              AppColors.coral,
              isCount: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AdminSearchLeaveRequestsScreen(
                          status: 'REJECTED', filter: 'admin_rejected')),
                );
              },
            ),
          ]),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isCount;
  final VoidCallback? onTap; // 클릭 시 실행할 함수

  const _StatItem(
    this.label,
    this.value,
    this.color, {
    this.isCount = false,
    this.onTap, // optional parameter로 추가!
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        Text(label),
        Text(
          value.toString(),
          style: TextStyle(color: color),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
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

          // 터치 가능하게 GestureDetector로 감싸기 (onTap이 있으면 반응)
          return Expanded(
            child: GestureDetector(
              onTap: item.onTap,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  Text(displayValue,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(item.label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
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