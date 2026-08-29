import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;

void main() {
  setUp(() async {
    await di.getIt.reset();
  });

  testWidgets('Splash opens login when onboarding is done without session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    FlutterSecureStorage.setMockInitialValues({});

    await di.init();

    await tester.pumpWidget(const TTMailApp());

    expect(find.byType(TTMailApp), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));

    await tester.pumpAndSettle();

    expect(find.text('Sign in to your intelligent inbox'), findsOneWidget);
  });

  testWidgets('Splash opens onboarding on first launch without session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await di.init();

    await tester.pumpWidget(const TTMailApp());

    await tester.pump(const Duration(milliseconds: 1600));

    await tester.pumpAndSettle();

    expect(find.text('Connect your inbox'), findsOneWidget);
  });

  testWidgets('Splash opens main navigation with existing session', (
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

    await tester.pump(const Duration(milliseconds: 1600));

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
