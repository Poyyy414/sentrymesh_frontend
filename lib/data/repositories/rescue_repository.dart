import '../../core/services/lora/lora_service.dart';
import '../../core/services/location_service.dart';
import '../models/rescue_location_model.dart';
import '../models/rescue_navigation_model.dart';
import '../models/rescue_request_model.dart';
import '../sources/remote/rescue_api.dart';
import '../../shared/enums/rescue_status.dart';

class RescueRepository {
  const RescueRepository({
    required RescueApi remote,
    required LoRaService loraService,
  }) : _remote = remote,
       _loraService = loraService;

  final RescueApi _remote;
  final LoRaService _loraService;

  Future<List<RescueRequestModel>> fetchRequests() async {
    final payload = await _remote.fetchRequests();
    final items = payload['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, Object?>>()
        .map(RescueRequestModel.fromJson)
        .toList();
  }

  Future<RescueRequestModel> submitRequest(RescueRequestModel request) async {
    try {
      final payload = await _remote.createRequest(request);
      if (payload.isEmpty) {
        return request;
      }

      return RescueRequestModel.fromJson(payload);
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

  Future<RescueLocationModel?> updateRequestLocation({
    required String id,
    required RescueLocationModel location,
  }) async {
    final payload = await _remote.updateRequestLocation(
      id: id,
      location: location,
    );
    if (payload.isEmpty) {
      return location;
    }

    return RescueLocationModel.fromJson(payload);
  }

  Future<RescueRequestModel?> updateRequestStatus({
    required String id,
    required RescueStatus status,
  }) async {
    final payload = await _remote.updateRequestStatus(id: id, status: status);
    if (payload.isEmpty) {
      return null;
    }

    return RescueRequestModel.fromJson(payload);
  }

  Future<RescueLocationModel?> fetchRequestLocation(String id) async {
    final payload = await _remote.fetchRequestLocation(id);
    if (payload.isEmpty) {
      return null;
    }

    return RescueLocationModel.fromJson(payload);
  }

  Future<RescueNavigationModel?> fetchNavigation({
    required String id,
    required GeoPoint responderLocation,
  }) async {
    final payload = await _remote.fetchRequestNavigation(
      id: id,
      responderLocation: responderLocation,
    );
    if (payload.isEmpty) {
      return null;
    }

    return RescueNavigationModel.fromJson(payload);
  }
}
