import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:tt_mail_assistant/domain/entities/notification.dart';
import 'package:tt_mail_assistant/domain/repositories/notification_repository.dart';


class NotificationService {


  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;


  final NotificationRepository notificationRepository;


  NotificationService({
    required this.notificationRepository,
  });



  Future<void> init() async {


    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );



    final token = await _messaging.getToken();

    debugPrint(
      "FCM TOKEN: $token",
    );



    FirebaseMessaging.onMessage.listen(
          (RemoteMessage message) async {


        debugPrint(
          "Foreground notification received",
        );


        final notification = NotificationEntity(

          id: message.messageId ??
              DateTime.now().toString(),

          title: message.notification?.title ??
              "",

          body: message.notification?.body ??
              "",

          type: message.data["type"] ?? "",

          createdAt: DateTime.now(),

          isRead: false,

        );



        await notificationRepository
            .saveNotification(notification);

      },
    );





    FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) async {


        debugPrint(
          "Notification clicked",
        );



        final notification = NotificationEntity(

          id: message.messageId ??
              DateTime.now().toString(),

          title: message.notification?.title ??
              "",

          body: message.notification?.body ??
              "",

          type: message.data["type"] ?? "",

          createdAt: DateTime.now(),

          isRead: false,

        );



        await notificationRepository
            .saveNotification(notification);



        // TODO Navigation

      },
    );






    final initialMessage =
    await FirebaseMessaging.instance
        .getInitialMessage();



    if(initialMessage != null){


      debugPrint(
        "Opened from terminated state",
      );



      final notification = NotificationEntity(

        id: initialMessage.messageId ??
            DateTime.now().toString(),

        title: initialMessage.notification?.title ??
            "",

        body: initialMessage.notification?.body ??
            "",

        type: initialMessage.data["type"] ?? "",

        createdAt: DateTime.now(),

        isRead: false,

      );



      await notificationRepository
          .saveNotification(notification);


    }


  }


}




Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {


  await Firebase.initializeApp();


  debugPrint(
    "Background message received",
  );


  debugPrint(
    message.data.toString(),
  );

}