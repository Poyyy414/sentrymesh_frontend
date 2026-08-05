import '../../../data/models/sensor_node_model.dart';
import '../offline/sync_queue.dart';

class LoRaDistressPing {
  const LoRaDistressPing({
    required this.nodeId,
    required this.sentAt,
    this.payload = const {},
  });

  final String nodeId;
  final DateTime sentAt;
  final Map<String, Object?> payload;
}

abstract class LoRaService {
  Future<void> sendDistressPing(LoRaDistressPing ping);
  Future<List<SensorNodeModel>> readNearbyNodes();
}

// Stub used while no real LoRa hardware is available. Pings are written to
// the shared SyncQueue (persisted to disk) so they survive app restarts and
// are replayed against /rescue-requests once connectivity is restored.
class OfflineLoRaService implements LoRaService {
  OfflineLoRaService({required SyncQueue syncQueue}) : _syncQueue = syncQueue;

  final SyncQueue _syncQueue;

  @override
  Future<void> sendDistressPing(LoRaDistressPing ping) async {
    await _syncQueue.enqueue(
      SyncOperation(
        id: 'lora-${ping.nodeId}-${ping.sentAt.microsecondsSinceEpoch}',
        type: 'sos',
        endpoint: '/rescue-requests',
        method: 'POST',
        body: {
          'node_id': ping.nodeId,
          'sent_at': ping.sentAt.toIso8601String(),
          ...ping.payload,
        },
        createdAt: ping.sentAt,
      ),
    );
  }

  @override
  Future<List<SensorNodeModel>> readNearbyNodes() async {
    return const [];
  }
}
