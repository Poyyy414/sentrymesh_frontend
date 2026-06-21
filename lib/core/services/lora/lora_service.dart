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

/// A short text message addressed to a recipient phone number, relayed over the
/// LoRaWAN mesh when no internet connection is available.
class LoRaTextMessage {
  const LoRaTextMessage({
    required this.toNumber,
    required this.body,
    required this.sentAt,
    this.fromName,
  });

  final String toNumber;
  final String body;
  final DateTime sentAt;
  final String? fromName;
}

abstract class LoRaService {
  Future<void> sendDistressPing(LoRaDistressPing ping);
  Future<void> sendTextMessage(LoRaTextMessage message);
  Future<List<SensorNodeModel>> readNearbyNodes();
}

class OfflineLoRaService implements LoRaService {
  final List<LoRaDistressPing> _queuedPings = [];
  final List<LoRaTextMessage> _queuedMessages = [];

  @override
  Future<void> sendDistressPing(LoRaDistressPing ping) async {
    _queuedPings.add(ping);
  }

  @override
  Future<void> sendTextMessage(LoRaTextMessage message) async {
    _queuedMessages.add(message);
  }

  @override
  Future<List<SensorNodeModel>> readNearbyNodes() async {
    return const [];
  }

  List<LoRaDistressPing> get queuedPings => List.unmodifiable(_queuedPings);

  List<LoRaTextMessage> get queuedMessages =>
      List.unmodifiable(_queuedMessages);
}
