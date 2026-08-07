import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;


void main() {

  testWidgets('Splash opens main navigation', (
      WidgetTester tester,
      ) async {

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await di.init();

    await tester.pumpWidget(const TTMailApp());

    expect(find.byType(TTMailApp), findsOneWidget);


    await tester.pump(
      const Duration(milliseconds: 1600),
    );

    await tester.pumpAndSettle();


    expect(
      find.text('Home'),
      findsOneWidget,
    );

  });



  testWidgets('Splash opens main navigation with existing session', (
      WidgetTester tester,
      ) async {

    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
    });

    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-access-token',
      'backend_session_token': 'test-backend-token',
      'user_id': 'user-1',
      'user_email': 'test@example.com',
    });


    await di.init();


    await tester.pumpWidget(const TTMailApp());


    await tester.pump(
      const Duration(milliseconds: 1600),
    );

    await tester.pumpAndSettle();


    expect(
      find.text('Home'),
      findsOneWidget,
    );

  });

}
