import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; 

// 휴가 신청 상태(대기/승인/반려/취소)를 색상 텍스트로 표시
// 상태 뱃지: 대기(amber)/승인(sage)/반려(coral)/취소(textMuted) 색상
class LeaveStatusBadge extends StatelessWidget {
  final String status;
  const LeaveStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PENDING' => ('대기', AppColors.amber),
      'APPROVED' => ('승인', AppColors.sage),
      'REJECTED' => ('반려', AppColors.coral),
      'CANCELLED' => ('취소', AppColors.textMuted),
      _ => (status, AppColors.textMuted),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.w700),
      ),
    );
  }
}