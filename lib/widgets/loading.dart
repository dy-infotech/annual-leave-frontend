import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 화면 전체 로딩 표시 (primary 색상).
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: AppColors.slate));
  }
}

/// 버튼 내부 로딩 스피너.
class ButtonSpinner extends StatelessWidget {
  final double size;
  final Color color;

  const ButtonSpinner({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
