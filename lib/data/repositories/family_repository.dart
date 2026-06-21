import '../../core/services/lora/lora_service.dart';
import '../models/family_member_model.dart';
import '../sources/remote/family_api.dart';

/// How a family message reached (or will reach) the recipient.
enum MessageDelivery {
  /// Delivered to the backend over the internet.
  online,

  /// No internet — queued on the LoRaWAN mesh for relay.
  loraMesh,
}

class FamilyRepository {
  const FamilyRepository({
    required FamilyApi remote,
    required LoRaService loraService,
  }) : _remote = remote,
       _lora = loraService;

  final FamilyApi _remote;
  final LoRaService _lora;

  Future<List<FamilyMemberModel>> fetchMembers() async {
    final payload = await _remote.fetchMembers();
    final items = payload['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, Object?>>()
        .map(FamilyMemberModel.fromJson)
        .toList();
  }

  Future<FamilyMemberModel> addMember({
    required String name,
    required String relationship,
    required String status,
    String? phoneNumber,
  }) async {
    final payload = await _remote.addMember({
      'name': name,
      'relationship': relationship,
      'status': status,
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        'phone_number': phoneNumber,
    });

    return FamilyMemberModel.fromJson(payload);
  }

  Future<void> removeMember(String id) async {
    await _remote.removeMember(id);
  }

  /// Sends a text message to [toNumber]. Tries the backend first (which relays
  /// over the LoRaWAN gateway); if the network is unavailable, the message is
  /// queued on the local LoRa mesh for relay. Returns how it was delivered.
  Future<MessageDelivery> sendMessage({
    required String toNumber,
    required String body,
    String? toName,
    String? fromName,
  }) async {
    try {
      await _remote.sendMessage({
        'to_number': toNumber,
        'body': body,
        'to_name': ?toName,
        'from_name': ?fromName,
      });
      return MessageDelivery.online;
    } catch (_) {
      await _lora.sendTextMessage(
        LoRaTextMessage(
          toNumber: toNumber,
          body: body,
          sentAt: DateTime.now(),
          fromName: fromName,
        ),
      );
      return MessageDelivery.loraMesh;
    }
  }

  Future<void> updateMyStatus({
    required String name,
    required String status,
  }) async {
    await _remote.updateMyStatus(name: name, status: status);
  }
}
