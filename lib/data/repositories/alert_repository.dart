import '../../shared/enums/alert_severity.dart';
import '../../shared/enums/hazard_type.dart';
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

  Future<AlertModel> createAlert({
    required String title,
    required String location,
    required String message,
    required AlertSeverity severity,
    required HazardType hazardType,
  }) async {
    final payload = await _remote.createAlert({
      'title': title,
      'location': location,
      'message': message,
      'severity': severity.name,
      'hazard_type': hazardType.name,
      'issued_at': DateTime.now().toUtc().toIso8601String(),
    });
    return AlertModel.fromJson(payload);
  }
}
