import '../../core/services/connectivity_service.dart';
import '../../core/services/offline/offline_data_cache.dart';
import '../../core/services/offline/sync_queue.dart';
import '../models/alert_model.dart';
import '../sources/remote/alerts_api.dart';

class AlertRepository {
  const AlertRepository({
    required AlertsApi remote,
    required ConnectivityService connectivityService,
    required OfflineDataCache offlineDataCache,
    required SyncQueue syncQueue,
  }) : _remote = remote,
       _connectivityService = connectivityService,
       _offlineDataCache = offlineDataCache,
       _syncQueue = syncQueue;

  final AlertsApi _remote;
  final ConnectivityService _connectivityService;
  final OfflineDataCache _offlineDataCache;
  final SyncQueue _syncQueue;

  Future<List<AlertModel>> fetchAlerts() async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      return _offlineDataCache.getCachedAlerts();
    }

    try {
      final payload = await _remote.fetchAlerts();
      final items = payload['items'];
      if (items is! List) {
        return const [];
      }

      final alerts = items
          .whereType<Map<String, Object?>>()
          .map(AlertModel.fromJson)
          .toList();
      await _offlineDataCache.cacheAlerts(alerts);
      return alerts;
    } catch (_) {
      return _offlineDataCache.getCachedAlerts();
    }
  }

  Future<void> createAlert({
    required String title,
    required String message,
    required String location,
    required String severity,
    required String hazardType,
  }) async {
    final body = {
      'title': title,
      'message': message,
      'location': location,
      'severity': severity,
      'hazard_type': hazardType,
    };

    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      await _enqueue(body);
      throw const QueuedForSyncException();
    }

    try {
      await _remote.createAlert(body);
    } catch (_) {
      await _enqueue(body);
      throw const QueuedForSyncException();
    }
  }

  Future<void> _enqueue(Map<String, Object?> body) {
    return _syncQueue.enqueue(SyncOperation(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      type: 'alert_create',
      endpoint: '/alerts',
      method: 'POST',
      body: body,
      createdAt: DateTime.now(),
    ));
  }
}
