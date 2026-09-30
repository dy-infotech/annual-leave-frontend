import 'package:flutter/material.dart';
import 'package:annual_leave_frontend/core/theme/app_theme.dart';

// 사용자 등록 상태를 색상 텍스트로 표시
// 상태 뱃지: 미등록(textMuted)/등록(sage) 색상
class RegisteStatusBadge extends StatelessWidget {
  final String status;
  const RegisteStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      '등록' => ('등록', AppColors.sage),
      '미등록' => ('미등록', AppColors.textMuted),
      _ => (status, AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
