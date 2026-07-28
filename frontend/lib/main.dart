import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:tt_mail_assistant/app/app.dart';
import 'package:tt_mail_assistant/core/di/di.dart' as di;
import 'package:tt_mail_assistant/core/services/notification_service.dart';
import 'package:tt_mail_assistant/data/repositories/notification_repository_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  await di.init();

  final notificationService = NotificationService(
    notificationRepository: NotificationRepositoryImpl(),
  );

  await notificationService.init();

  runApp(const TTMailApp());
}