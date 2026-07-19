import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// 취소/승인/반려 확인 등, "제목 + 안내 문구(또는 입력 폼) + 취소/확인 버튼" 구조가
// 반복되던 다이얼로그들을 하나로 모음. content에 TextField 등 추가 입력 위젯을
// 넣을 수도 있어서(반려 사유 입력), 순수 텍스트 문구뿐 아니라 폼이 있는 경우도 커버한다.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required String confirmLabel,
  required Color confirmColor,
  String cancelLabel = '취소',
  double? titleFontSize,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: titleFontSize)),
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
}
