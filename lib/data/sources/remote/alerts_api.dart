import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AlertsApi {
  const AlertsApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchAlerts() {
    return _client.get(ApiEndpoints.alerts);
  }

  Future<Map<String, Object?>> createAlert(Map<String, Object?> data) {
    return _client.post(ApiEndpoints.alerts, body: data);
  }
}
