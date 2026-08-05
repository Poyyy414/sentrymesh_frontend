import 'dart:math';

import '../../core/services/connectivity_service.dart';
import '../../core/services/lora/lora_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/offline/offline_data_cache.dart';
import '../../core/services/offline/sync_queue.dart';
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
    required LoRaService loraService,
    required MapRepository mapRepository,
    required ConnectivityService connectivityService,
    required OfflineDataCache offlineDataCache,
    required SyncQueue syncQueue,
  }) : _remote = remote,
       _loraService = loraService,
       _mapRepository = mapRepository,
       _connectivityService = connectivityService,
       _offlineDataCache = offlineDataCache,
       _syncQueue = syncQueue;

  final RescueApi _remote;
  final LoRaService _loraService;
  final MapRepository _mapRepository;
  final ConnectivityService _connectivityService;
  final OfflineDataCache _offlineDataCache;
  final SyncQueue _syncQueue;

  Future<List<RescueRequestModel>> fetchRequests() async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      return _offlineDataCache.getCachedRescueRequests();
    }

    try {
      final payload = await _remote.fetchRequests();
      final items = payload['items'];
      if (items is! List) {
        return const [];
      }

      final requests = items
          .whereType<Map<String, Object?>>()
          .map(RescueRequestModel.fromJson)
          .toList();
      await _offlineDataCache.cacheRescueRequests(requests);
      return requests;
    } catch (_) {
      return _offlineDataCache.getCachedRescueRequests();
    }
  }

  Future<RescueRequestModel> submitRequest(RescueRequestModel request) async {
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      await _syncQueue.enqueue(SyncOperation(
        id: request.id,
        type: 'sos',
        endpoint: '/rescue-requests',
        method: 'POST',
        body: request.toCreateJson(),
        createdAt: DateTime.now(),
      ));
      await _loraService.sendDistressPing(
        LoRaDistressPing(
          nodeId: request.id,
          sentAt: request.createdAt,
          payload: request.toJson(),
        ),
      );
      return request;
    }

    try {
      final payload = await _remote.createRequest(request);
      if (payload.isEmpty) {
        return request;
      }

      return RescueRequestModel.fromJson(payload);
    } catch (_) {
      await _syncQueue.enqueue(SyncOperation(
        id: request.id,
        type: 'sos',
        endpoint: '/rescue-requests',
        method: 'POST',
        body: request.toCreateJson(),
        createdAt: DateTime.now(),
      ));
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

  Future<RescueLocationModel> updateRequestLocation({
    required String id,
    required RescueLocationModel location,
  }) async {
    final connectivity = await _connectivityService.currentStatus();
    if (connectivity == ConnectivityStatus.offline) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${id}_loc_${DateTime.now().millisecondsSinceEpoch}',
        type: 'location_update',
        endpoint: '/rescue-requests/$id/location',
        method: 'PATCH',
        body: location.toJson(),
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }

    try {
      final payload = await _remote.updateRequestLocation(
        id: id,
        location: location,
      );
      if (payload.isEmpty) {
        return location;
      }
      return RescueLocationModel.fromJson(payload);
    } catch (_) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${id}_loc_${DateTime.now().millisecondsSinceEpoch}',
        type: 'location_update',
        endpoint: '/rescue-requests/$id/location',
        method: 'PATCH',
        body: location.toJson(),
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }
  }

  Future<RescueRequestModel> updateRequestStatus({
    required String id,
    required RescueStatus status,
  }) async {
    final connectivity = await _connectivityService.currentStatus();
    if (connectivity == ConnectivityStatus.offline) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${id}_status_${DateTime.now().millisecondsSinceEpoch}',
        type: 'status_change',
        endpoint: '/rescue-requests/$id/status',
        method: 'PATCH',
        body: {'status': status.name},
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }

    try {
      final payload = await _remote.updateRequestStatus(id: id, status: status);
      if (payload.isEmpty) {
        throw const QueuedForSyncException(
          'Status change accepted but the server returned no confirmation.',
        );
      }
      return RescueRequestModel.fromJson(payload);
    } on QueuedForSyncException {
      rethrow;
    } catch (_) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${id}_status_${DateTime.now().millisecondsSinceEpoch}',
        type: 'status_change',
        endpoint: '/rescue-requests/$id/status',
        method: 'PATCH',
        body: {'status': status.name},
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }
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
    final status = await _connectivityService.currentStatus();
    if (status == ConnectivityStatus.offline) {
      return _offlineDataCache.getCachedEvacuationCenters();
    }

    try {
      final payload = await _remote.fetchEvacuationCenters();
      final items = payload['items'];
      if (items is! List) return const [];
      final centers = items
          .whereType<Map<String, Object?>>()
          .map(EvacuationCenterModel.fromJson)
          .toList();
      await _offlineDataCache.cacheEvacuationCenters(centers);
      return centers;
    } catch (_) {
      return _offlineDataCache.getCachedEvacuationCenters();
    }
  }

  Future<EvacuationCenterModel> updateEvacuationCenterOccupancy({
    required String id,
    required int currentOccupancy,
    String? status,
  }) async {
    final payload = await _remote.updateEvacuationCenterOccupancy(
      id: id,
      currentOccupancy: currentOccupancy,
      status: status,
    );
    return EvacuationCenterModel.fromJson(payload);
  }

  Future<RescueRequestModel> assignShelter({
    required String requestId,
    required String shelterId,
    required String shelterName,
    String? shelterAddress,
  }) async {
    final body = {
      'shelter_id': shelterId,
      'shelter_name': shelterName,
      'shelter_address': shelterAddress,
    };
    final connectivity = await _connectivityService.currentStatus();
    if (connectivity == ConnectivityStatus.offline) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${requestId}_shelter_${DateTime.now().millisecondsSinceEpoch}',
        type: 'shelter_assign',
        endpoint: '/rescue-requests/$requestId/shelter',
        method: 'PATCH',
        body: body,
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }

    try {
      final payload = await _remote.assignShelter(
        id: requestId,
        shelterId: shelterId,
        shelterName: shelterName,
        shelterAddress: shelterAddress,
      );
      if (payload.isEmpty) {
        throw const QueuedForSyncException(
          'Shelter assignment accepted but the server returned no confirmation.',
        );
      }
      return RescueRequestModel.fromJson(payload);
    } on QueuedForSyncException {
      rethrow;
    } catch (_) {
      await _syncQueue.enqueue(SyncOperation(
        id: '${requestId}_shelter_${DateTime.now().millisecondsSinceEpoch}',
        type: 'shelter_assign',
        endpoint: '/rescue-requests/$requestId/shelter',
        method: 'PATCH',
        body: body,
        createdAt: DateTime.now(),
      ));
      throw const QueuedForSyncException();
    }
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
