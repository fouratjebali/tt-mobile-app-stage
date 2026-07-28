import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository.dart';


class NotificationRepositoryImpl
    implements NotificationRepository {


  final List<NotificationEntity> _notifications = [];


  @override
  Future<void> saveNotification(
      NotificationEntity notification) async {

    _notifications.add(notification);

  }


  @override
  Future<List<NotificationEntity>> getNotifications() async {

    return _notifications;

  }


  @override
  Future<int> getUnreadCount() async {

    return _notifications
        .where((n) => !n.isRead)
        .length;

  }


  @override
  Future<void> markAsRead(String id) async {

    final index = _notifications
        .indexWhere((n) => n.id == id);

    if(index != -1){

      final old = _notifications[index];

      _notifications[index] = NotificationEntity(
        id: old.id,
        title: old.title,
        body: old.body,
        type: old.type,
        createdAt: old.createdAt,
        isRead: true,
      );

    }
  }
}