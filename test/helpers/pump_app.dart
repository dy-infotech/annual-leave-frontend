import 'package:annual_leave_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// 앱과 동일한 테마/로케일 환경으로 [home] 화면을 띄운다.
Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  List<SingleChildWidget> providers = const [],
}) async {
  final app = MaterialApp(
    theme: AppTheme.theme,
    locale: const Locale('ko', 'KR'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ko', 'KR')],
    home: home,
  );
  await tester.pumpWidget(
    providers.isEmpty
        ? app
        : MultiProvider(providers: providers, child: app),
  );
}

/// 무한 반복 애니메이션이 있는 화면에서는 pumpAndSettle이 타임아웃되므로
/// 정해진 시간만큼만 프레임을 진행시킬 때 사용한다.
Future<void> pumpFor(
  WidgetTester tester, {
  Duration duration = const Duration(seconds: 2),
  Duration step = const Duration(milliseconds: 100),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// [finder]가 나타날 때까지 프레임을 진행시킨다.
/// [timeout] 안에 나타나지 않으면 그대로 반환하므로, 호출부에서 expect로 확인한다.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 4),
  Duration step = const Duration(milliseconds: 100),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
    elapsed += step;
  }
}
