import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;
import 'package:tt_mail_assistant/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // Handle notifications when app is in background
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await NotificationService().init();

  await di.init();

  runApp(const TTMailApp());
}