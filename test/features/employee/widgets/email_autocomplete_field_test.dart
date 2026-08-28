import 'package:annual_leave_frontend/features/employee/widgets/email_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';

/// 이메일 도메인 자동완성 필드 테스트.
///
/// @ 뒤에 입력한 문자열로 도메인 후보를 좁혀 보여준다.
void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> pumpField(
    WidgetTester tester, {
    List<String>? domains,
    VoidCallback? onSubmitted,
  }) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EmailAutocompleteField(
            controller: controller,
            onSubmitted: onSubmitted,
            domains: domains ?? const ['gmail.com', 'naver.com', 'daum.net'],
          ),
        ),
      ),
    );
  }

  /// 후보 목록에 보이는 텍스트만 모은다(입력 필드의 텍스트는 제외).
  List<String> visibleOptions(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Text),
      ))
      .map((t) => t.data!)
      .toList();

  testWidgets('@를 입력하기 전에는 후보를 보여주지 않는다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong');
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('@만 입력하면 모든 도메인 후보가 나온다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong@');
    await tester.pumpAndSettle();

    expect(visibleOptions(tester),
        ['hong@gmail.com', 'hong@naver.com', 'hong@daum.net']);
  });

  testWidgets('도메인 앞글자를 입력하면 후보가 좁혀진다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong@na');
    await tester.pumpAndSettle();

    expect(visibleOptions(tester), ['hong@naver.com']);
  });

  testWidgets('일치하는 도메인이 없으면 후보가 사라진다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong@zzz');
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('입력값이 유일한 후보와 완전히 같으면 후보를 감춘다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong@naver.com');
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('후보를 누르면 입력값이 채워진다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'hong@g');
    await tester.pumpAndSettle();
    await tester.tap(find.text('hong@gmail.com'));
    await tester.pumpAndSettle();

    expect(controller.text, 'hong@gmail.com');
  });

  testWidgets('앞부분(로컬 파트)이 후보에 그대로 유지된다', (tester) async {
    await pumpField(tester);

    await tester.enterText(find.byType(TextField), 'lee.seo-woo@d');
    await tester.pumpAndSettle();

    expect(visibleOptions(tester), ['lee.seo-woo@daum.net']);
  });

  testWidgets('제출하면 콜백이 불린다', (tester) async {
    var submitted = 0;
    await pumpField(tester, onSubmitted: () => submitted++);

    await tester.enterText(find.byType(TextField), 'hong@gmail.com');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(submitted, 1);
  });

  testWidgets('도메인 목록을 직접 넘기면 그 목록만 후보가 된다', (tester) async {
    await pumpField(tester, domains: const ['dyinfotech.com']);

    await tester.enterText(find.byType(TextField), 'hong@');
    await tester.pumpAndSettle();

    expect(visibleOptions(tester), ['hong@dyinfotech.com']);
  });
}
