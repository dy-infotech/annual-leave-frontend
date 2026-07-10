import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 공통 확인 다이얼로그. 확인 시 true, 취소/닫기 시 false 반환.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required String confirmLabel,
  required Color confirmColor,
  String cancelLabel = '취소',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel, style: const TextStyle(color: AppColors.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 공통 스낵바 메시지 표시.
void showSnackBarMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// 공통 기간 선택 다이얼로그(현재 기준 ±1년, primary 색상 통일).
Future<DateTimeRange?> pickLeaveDateRange(
  BuildContext context, {
  DateTimeRange? initialRange,
}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 1),
    initialDateRange: initialRange,
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.slate),
      ),
      child: child!,
    ),
  );
}
