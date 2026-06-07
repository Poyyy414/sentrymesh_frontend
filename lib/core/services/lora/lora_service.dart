import '../../../data/models/sensor_node_model.dart';

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

class OfflineLoRaService implements LoRaService {
  final List<LoRaDistressPing> _queuedPings = [];

  @override
  Future<void> sendDistressPing(LoRaDistressPing ping) async {
    _queuedPings.add(ping);
  }

  @override
  Future<List<SensorNodeModel>> readNearbyNodes() async {
    return const [];
  }

  List<LoRaDistressPing> get queuedPings => List.unmodifiable(_queuedPings);
}
