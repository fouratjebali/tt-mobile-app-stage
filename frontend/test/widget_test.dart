import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;

void main() {
  testWidgets('Splash routes first launch to onboarding', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await di.init();

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
    FlutterSecureStorage.setMockInitialValues({});
    await di.init();

    await tester.pumpWidget(const TTMailApp());
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your intelligent inbox'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Connect your inbox'), findsNothing);
  });

  testWidgets('Splash opens inbox when a secure session exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-access-token',
      'backend_session_token': 'test-backend-token',
      'user_id': 'user-1',
      'user_email': 'test@example.com',
    });
    await di.init();

    await tester.pumpWidget(const TTMailApp());
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });
}
