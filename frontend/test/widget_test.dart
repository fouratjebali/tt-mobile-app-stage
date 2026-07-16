import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tt_mail_assistant/app/app.dart';

void main() {
  testWidgets('Splash routes first launch to onboarding', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TTMailApp());

    expect(find.byType(TTMailApp), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('TT Mail Assistant'), findsOneWidget);
    expect(find.text('Connect your inbox'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Splash skips onboarding after first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});

    await tester.pumpWidget(const TTMailApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Connect your inbox'), findsNothing);
  });
}
