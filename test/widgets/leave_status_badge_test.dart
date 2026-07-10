import 'package:annual_leave_frontend/theme/app_theme.dart';
import 'package:annual_leave_frontend/widgets/leave_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, String status) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LeaveStatusBadge(status: status),
        ),
      ),
    );
  }

  final statuses = {
    'PENDING': ('대기', AppColors.amber),
    'APPROVED': ('승인', AppColors.sage),
    'REJECTED': ('반려', AppColors.coral),
    'CANCELLED': ('취소', AppColors.textMuted),
  };

  for (final MapEntry(key: status, value: expected) in statuses.entries) {
    testWidgets('renders the $status label and color', (tester) async {
      await pumpBadge(tester, status);

      final text = tester.widget<Text>(find.text(expected.$1));

      expect(text.style!.color, expected.$2);
    });
  }

  testWidgets('renders an unknown status as muted text', (tester) async {
    await pumpBadge(tester, 'EXPIRED');

    final text = tester.widget<Text>(find.text('EXPIRED'));

    expect(text.style!.color, AppColors.textMuted);
  });
}
