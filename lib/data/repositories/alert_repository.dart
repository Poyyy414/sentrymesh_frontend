import '../models/alert_model.dart';
import '../sources/remote/alerts_api.dart';

class AlertRepository {
  const AlertRepository({required AlertsApi remote}) : _remote = remote;

  final AlertsApi _remote;

  Future<List<AlertModel>> fetchAlerts() async {
    final payload = await _remote.fetchAlerts();
    final items = payload['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, Object?>>()
        .map(AlertModel.fromJson)
        .toList();
  }
}
