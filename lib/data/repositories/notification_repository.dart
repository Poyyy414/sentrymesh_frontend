import '../models/notification_model.dart';
import '../sources/remote/notifications_api.dart';

class NotificationRepository {
  const NotificationRepository({required NotificationsApi remote})
      : _remote = remote;

  final NotificationsApi _remote;

  Future<List<NotificationModel>> fetchNotifications() async {
    try {
      final payload = await _remote.fetchNotifications();
      final items = payload['items'];
      if (items is! List) {
        return const [];
      }
      return items
          .whereType<Map<String, Object?>>()
          .map(NotificationModel.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> markRead(String id) async {
    await _remote.markRead(id);
  }
}
