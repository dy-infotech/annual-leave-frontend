import 'package:annual_leave_frontend/providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String routeName,
      {bool replace = false}) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    Navigator.pop(context); // Drawer 닫기

    if (currentRoute == routeName) return;

    if (replace) {
      Navigator.pushReplacementNamed(context, routeName);
    } else {
      Navigator.pushNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final info = auth.employeeInfo;

    // 관리자 전용 네이비 컬러 정의
    const navyPrimary = Color(0xFF1E293B); // 고급스러운 딥 네이비
    const navyMuted = Color(0xFF64748B); // 은은한 서브 네이비

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 스크롤되는 영역: 프로필 + 메뉴 항목들
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info != null
                                ? '${info.name} ${info.position}'
                                : (auth.name ?? ''),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${info?.department ?? ''} · ${info?.employeeNumber ?? ''}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 8),

                    _NavItem(
                        label: '대시보드',
                        onTap: () =>
                            _navigate(context, '/dashboard', replace: true)),
                    _NavItem(
                        label: '휴가 신청',
                        onTap: () => _navigate(context, '/leave-request')),
                    _NavItem(
                        label: '신청 목록',
                        onTap: () => _navigate(context, '/all-leave-requests')),
                    _NavItem(
                        label: '내 정보',
                        onTap: () => _navigate(context, '/my-info')),

                    // 관리자 섹션
                    if (info != null && info.role == 'ADMIN') ...[
                      const Padding(
                        padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Divider(
                            color: Color.fromARGB(255, 199, 178, 147),
                            thickness: 0.5),
                      ),
                      const Padding(
                        padding:
                        EdgeInsets.only(left: 24.0, top: 4.0, bottom: 8.0),
                        child: Text(
                          '관리자 전용 Menu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: navyMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _NavItem(
                          label: '승인 대기 목록',
                          isAdmin: true,
                          adminTextColor: navyPrimary,
                          onTap: () => _navigate(context, '/pending-approval')),
                      _NavItem(
                          label: '사용자 등록 관리',
                          isAdmin: true,
                          adminTextColor: navyPrimary,
                          onTap: () =>
                              _navigate(context, '/signup_manage_screen')),
                      _NavItem(
                          label: '사용자 정보 조회',
                          isAdmin: true,
                          adminTextColor: navyPrimary,
                          onTap: () => _navigate(
                              context, '/search_employee_number_screen')),
                    ],
                  ],
                ),
              ),
            ),

            // 하단 고정 영역: 로그아웃
            const Divider(height: 1, color: AppColors.divider),
            _NavItem(
              label: '로그아웃',
              color: AppColors.coral,
              onTap: () async {
                Navigator.pop(context);
                final dashboardProvider = context.read<DashboardProvider>();
                final authProvider = context.read<AuthProvider>();

                await dashboardProvider.closeSubscription();
                await authProvider.logout();

                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (_) => false,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isAdmin;
  final Color? adminTextColor;

  const _NavItem({
    required this.label,
    required this.onTap,
    this.color,
    this.isAdmin = false,
    this.adminTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 관리자 메뉴만 은은한 좌우 패딩 박스로 감싸 시각적 레이어를 분리
      margin: isAdmin
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        // 아이콘이 없으므로 배경색을 미세하게 조정하여 눈이 편안한 네이비 슬레이트 베이지를 연출
        color: isAdmin
            ? const Color(0xFF1E293B).withOpacity(0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // 일반 메뉴(horizontal: 24)와 관리자 메뉴(12 + 12 = 24)의 텍스트 시작 포인트를 정확히 일치
          padding:
              EdgeInsets.symmetric(horizontal: isAdmin ? 12 : 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isAdmin ? FontWeight.w700 : FontWeight.w600,
                    color: color ??
                        (isAdmin ? adminTextColor : AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
