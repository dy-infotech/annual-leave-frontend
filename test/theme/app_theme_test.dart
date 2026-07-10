import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds the application theme from the shared color palette', () {
    final theme = AppTheme.theme;

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.slate);
    expect(theme.colorScheme.secondary, AppColors.sage);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.error, AppColors.coral);
    expect(theme.appBarTheme.backgroundColor, AppColors.background);
    expect(theme.appBarTheme.foregroundColor, AppColors.textPrimary);
    expect(theme.drawerTheme.backgroundColor, AppColors.surface);
  });
}
