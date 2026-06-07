import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AlertsApi {
  const AlertsApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchAlerts() {
    return _client.get(ApiEndpoints.alerts);
  }
}
