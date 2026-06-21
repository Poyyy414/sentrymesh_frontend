import 'dart:math';

import '../../core/services/location_service.dart';
import '../models/evacuation_center_model.dart';
import '../models/rescue_location_model.dart';
import '../models/rescue_navigation_model.dart';
import '../models/rescue_request_model.dart';
import '../sources/remote/rescue_api.dart';
import '../../shared/enums/rescue_status.dart';
import 'map_repository.dart';

class RescueRepository {
  const RescueRepository({
    required RescueApi remote,
    required MapRepository mapRepository,
  }) : _remote = remote,
       _mapRepository = mapRepository;

  final RescueApi _remote;
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
    // No offline relay yet (LoRa is on standby) — failures propagate to the
    // caller so the user sees an honest "couldn't send" error.
    final payload = await _remote.createRequest(request);
    if (payload.isEmpty) {
      return request;
    }

    return RescueRequestModel.fromJson(payload);
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
    String? responderId,
  }) async {
    final payload = await _remote.updateRequestStatus(
      id: id,
      status: status,
      responderId: responderId,
    );
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
      bearingDegrees: _bearing(responderLocation, residentLocation.point),
      route: route,
      navigationUrl:
          'https://www.google.com/maps/dir/?api=1&destination=${residentLocation.latitude},${residentLocation.longitude}&travelmode=driving',
    );
  }

  Future<List<EvacuationCenterModel>> fetchEvacuationCenters() async {
    final payload = await _remote.fetchEvacuationCenters();
    final items = payload['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, Object?>>()
        .map(EvacuationCenterModel.fromJson)
        .toList();
  }

  Future<EvacuationCenterModel> createEvacuationCenter({
    required String name,
    required String address,
    required int capacity,
    required double latitude,
    required double longitude,
  }) async {
    final payload = await _remote.createEvacuationCenter(
      name: name,
      address: address,
      capacity: capacity,
      latitude: latitude,
      longitude: longitude,
    );
    return EvacuationCenterModel.fromJson(payload);
  }

  Future<void> deleteEvacuationCenter(String id) async {
    await _remote.deleteEvacuationCenter(id);
  }

  Future<RescueRequestModel?> assignShelter({
    required String requestId,
    required String shelterId,
    required String shelterName,
    String? shelterAddress,
  }) async {
    final payload = await _remote.assignShelter(
      id: requestId,
      shelterId: shelterId,
      shelterName: shelterName,
      shelterAddress: shelterAddress,
    );
    if (payload.isEmpty) return null;
    return RescueRequestModel.fromJson(payload);
  }

  Future<RescueRequestModel?> assignResponder({
    required String requestId,
    required String responderId,
    required String responderName,
  }) async {
    final payload = await _remote.assignResponder(
      id: requestId,
      responderId: responderId,
      responderName: responderName,
    );
    if (payload.isEmpty) return null;
    return RescueRequestModel.fromJson(payload);
  }

  double _bearing(GeoPoint from, GeoPoint to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLon = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}
