import '../entities/notification_entity.dart';
abstract class NotificationRepository {

  Future<List<NotificationEntity>> getNotifications();

  Future<void> saveNotification(
      NotificationEntity notification
      );

  Future<void> markAsRead(String id);

  Future<int> getUnreadCount();
}