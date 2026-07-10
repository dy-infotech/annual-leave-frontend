import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centered error message with a retry button, shown when a screen fails to
/// load its data. Keeps failures visible instead of silently rendering an
/// empty state.
class ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
