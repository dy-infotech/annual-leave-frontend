import 'dart:async';
import 'package:annual_leave_frontend/core/network/api_client.dart';
import 'package:annual_leave_frontend/core/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:annual_leave_frontend/features/auth/state/auth_session.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';

/// 모든 화면이 공유하는 좌측 메뉴(Drawer).
///
/// 상단에 내 이름/직급/팀/사번을, 가운데에 이동 메뉴를, 하단에 로그아웃을 보여준다.
/// 메뉴 노출은 `AuthSession.employeeInfo`의 role/직급으로만 결정하는 UX용 분기이며 보안 경계가 아니다.
/// 실제 접근 권한은 서버가 요청마다 다시 검증한다.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  /// 메뉴를 닫고 [routeName]으로 이동한다. 이미 그 화면이면 이동하지 않는다.
  /// [replace]가 true면 현재 화면을 대체한다. (대시보드로 돌아갈 때 화면이 쌓이지 않게 하려는 용도)
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
    final auth = context.watch<AuthSession>();
    final info = auth.employeeInfo;

    // 관리자 메뉴 전용 색상 (일반 메뉴는 AppColors 사용)
    const navyPrimary = Color(0xFF1E293B); // 관리자 메뉴 글자색
    const navyMuted = Color(0xFF64748B); // '관리자 전용 Menu' 소제목 색

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
                    // 프로필: 내 정보가 아직 없으면 로그인 응답의 이름만 표시한다.
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
                            '${info?.team ?? ''} · ${info?.employeeNumber ?? ''}',
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
                    // PM 관리자 또는 현재 인사권자인 CEO에게 관리 섹션을 노출한다.
                    // CEO와 PM은 별도 개념이므로 CEO에게 role == ADMIN을 요구하지 않는다.
                    if (info != null &&
                        (info.role == 'ADMIN' || info.isCeo)) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
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
                      if (info.role == 'ADMIN')
                        _NavItem(
                            label: '결재 대기 목록',
                            isAdmin: true,
                            adminTextColor: navyPrimary,
                            onTap: () =>
                                _navigate(context, '/pending-approval')),
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
                      // 아래 두 메뉴는 관리자 중에서도 CEO(직급 '사장' 또는 '대표이사')에게만 노출한다.
                      if (info.isCeo)
                        _NavItem(
                            label: '부서 및 팀 관리',
                            isAdmin: true,
                            adminTextColor: navyPrimary,
                            onTap: () =>
                                _navigate(context, '/department-team-manage')),
                      if (info.isCeo)
                        _NavItem(
                            label: '관리자별 관리팀 설정',
                            isAdmin: true,
                            adminTextColor: navyPrimary,
                            onTap: () => _navigate(context, '/admin-settings')),
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
                // Drawer는 pop 직후 dispose될 수 있으므로, async 작업 전에
                // 화면 전환에 사용할 root navigator와 세션 객체를 확보한다.
                final navigator = Navigator.of(context, rootNavigator: true);
                final authProvider = context.read<AuthSession>();

                // 로그아웃하면 저장된 FCM token 정보가 지워지므로 먼저 읽어 둔다.
                FcmLogoutContext? cleanupContext;
                try {
                  cleanupContext =
                      await FcmService.instance.captureLogoutContext();
                } catch (e) {
                  debugPrint('FCM 로그아웃 정보 캡처 실패: $e');
                }

                Navigator.pop(context);

                // 로컬 인증 상태를 FCM SDK/네트워크보다 먼저 종료한다.
                // 서버에는 FCM token을 함께 보내 서버 쪽 FCM 연결도 해제하게 한다.
                await authProvider.logout(fcmToken: cleanupContext?.fcmToken);
                final loggedOutGeneration = ApiClient().sessionGeneration;

                if (navigator.mounted) {
                  navigator.pushNamedAndRemoveUntil(
                    '/login',
                    (_) => false,
                  );
                }

                // 이 기기의 FCM 정리는 화면 전환을 막지 않도록 기다리지 않고 백그라운드로 처리한다.
                // 10초 안에 끝나지 않거나 실패해도 로그아웃 자체에는 영향이 없다.
                if (cleanupContext != null) {
                  unawaited(
                    FcmService.instance
                        .cleanupCapturedLogout(
                          cleanupContext,
                          expectedAuthGeneration: loggedOutGeneration,
                        )
                        .timeout(const Duration(seconds: 10))
                        .catchError((Object e) {
                      debugPrint('FCM 로그아웃 정리 실패: $e');
                    }),
                  );
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

/// Drawer의 메뉴 한 줄. [isAdmin]이 true면 관리자 메뉴 스타일(연한 배경 박스, 굵은 글씨)로 그린다.
class _NavItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  /// 글자색을 직접 지정할 때 사용한다. (예: 로그아웃) 지정하면 [adminTextColor]보다 우선한다.
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
      // 관리자 메뉴만 좌우 여백이 있는 박스로 감싸 일반 메뉴와 구분한다.
      margin: isAdmin
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 2)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        // 관리자 메뉴 박스의 은은한 배경색
        color: isAdmin
            ? const Color(0xFF1E293B).withOpacity(0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // 일반 메뉴(horizontal: 24)와 관리자 메뉴(12 + 12 = 24)의 텍스트 시작 위치를 맞춘다.
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
