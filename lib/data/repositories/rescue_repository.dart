import '../../core/services/lora/lora_service.dart';
import '../models/rescue_request_model.dart';
import '../sources/remote/rescue_api.dart';

class RescueRepository {
  const RescueRepository({
    required RescueApi remote,
    required LoRaService loraService,
  })  : _remote = remote,
        _loraService = loraService;

  final RescueApi _remote;
  final LoRaService _loraService;

  Future<void> submitRequest(RescueRequestModel request) async {
    try {
      await _remote.createRequest(request);
    } catch (_) {
      await _loraService.sendDistressPing(
        LoRaDistressPing(
          nodeId: request.id,
          sentAt: request.createdAt,
          payload: request.toJson(),
        ),
      );
      rethrow;
    }
  }
}
