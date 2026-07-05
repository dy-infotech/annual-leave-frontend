import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// 휴가 신청 상태(대기/승인/반려)를 색상 텍스트로 표시
class LeaveStatusBadge extends StatelessWidget {
  final String status;
  const LeaveStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PENDING' => ('대기', AppColors.amber),
      'APPROVED' => ('승인', AppColors.sage),
      'REJECTED' => ('반려', AppColors.coral),
      _ => (status, AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
