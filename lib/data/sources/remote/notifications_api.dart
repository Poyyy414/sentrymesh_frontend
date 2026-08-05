import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class NotificationsApi {
  const NotificationsApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchNotifications() async {
    return _client.get(ApiEndpoints.notifications);
  }

  Future<Map<String, Object?>> markRead(String id) async {
    return _client.patch(ApiEndpoints.notificationRead(id));
  }
}
