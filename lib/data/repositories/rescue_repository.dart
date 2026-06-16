import '../../core/services/lora/lora_service.dart';
import '../../core/services/location_service.dart';
import '../models/rescue_location_model.dart';
import '../models/rescue_navigation_model.dart';
import '../models/rescue_request_model.dart';
import '../sources/remote/rescue_api.dart';
import '../../shared/enums/rescue_status.dart';
import 'map_repository.dart';

class RescueRepository {
  const RescueRepository({
    required RescueApi remote,
    required LoRaService loraService,
    required MapRepository mapRepository,
  }) : _remote = remote,
       _loraService = loraService,
       _mapRepository = mapRepository;

  final RescueApi _remote;
  final LoRaService _loraService;
  final MapRepository _mapRepository;

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
    return location;
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
    final lat = payload['latitude'];
    final lon = payload['longitude'];
    if (lat == null || lon == null) return null;
    final latitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final longitude = lon is num ? lon.toDouble() : double.tryParse('$lon');
    if (latitude == null || longitude == null) return null;
    return RescueLocationModel(
      latitude: latitude,
      longitude: longitude,
      locationLabel: payload['location_label'] as String?,
    );
  }

  Future<RescueNavigationModel?> fetchNavigation({
    required String id,
    required GeoPoint responderLocation,
  }) async {
    final residentLocation = await fetchRequestLocation(id);
    if (residentLocation == null) {
      return null;
    }

    final route = await _mapRepository.fetchSafeRoute(
      origin: responderLocation,
      destination: residentLocation.point,
    );

    return RescueNavigationModel(
      directDistanceKm: route?.distanceKm ?? 0,
      bearingDegrees: 0,
      route: route,
      navigationUrl:
          'https://www.google.com/maps/dir/?api=1&destination=${residentLocation.latitude},${residentLocation.longitude}&travelmode=driving',
    );
  }
}
