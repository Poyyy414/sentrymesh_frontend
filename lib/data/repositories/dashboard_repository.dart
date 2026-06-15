import 'alert_repository.dart';

class DashboardRepository {
  const DashboardRepository({required AlertRepository alertRepository})
    : _alertRepository = alertRepository;

  final AlertRepository _alertRepository;

  Future<int> activeAlertCount() async {
    final alerts = await _alertRepository.fetchAlerts();
    return alerts.length;
  }
}
