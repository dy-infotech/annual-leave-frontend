import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String routeName, {bool replace = false}) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    Navigator.pop(context); // Drawer 닫기

    // 이미 같은 화면이면 재이동하지 않음 (GlobalKey 충돌 방지)
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

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info != null ? '${info.name} ${info.position}' : (auth.name ?? ''),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${info?.department ?? ''} · ${info?.employeeNo ?? ''}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),

            _NavItem(label: '대시보드', onTap: () => _navigate(context, '/dashboard', replace: true)),
            _NavItem(label: '휴가 신청', onTap: () => _navigate(context, '/leave-request')),
            _NavItem(label: '내 신청 목록', onTap: () => _navigate(context, '/my-leave-requests')),
            _NavItem(label: '전체 신청 목록', onTap: () => _navigate(context, '/all-leave-requests')),

            if (auth.isAdmin)
              _NavItem(label: '승인 대기 목록', onTap: () => _navigate(context, '/pending-approval')),

            _NavItem(label: '내 정보', onTap: () => _navigate(context, '/my-info')),

            const Spacer(),
            const Divider(height: 1, color: AppColors.divider),
            _NavItem(
              label: '로그아웃',
              color: AppColors.coral,
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
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

  const _NavItem({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}