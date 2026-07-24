import '../../core/services/location_service.dart';
import '../../core/services/map_service.dart';
import '../models/route_model.dart';
import '../sources/remote/map_api.dart';

class MapRepository {
  const MapRepository({required MapApi remote, required MapService mapService})
    : _remote = remote,
      _mapService = mapService;

  final MapApi _remote;
  final MapService _mapService;

  Future<RouteModel?> fetchSafeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    try {
      final payload = await _remote.fetchSafeRoute(
        origin: origin,
        destination: destination,
      );
      final route = RouteModel.fromJson(payload);
      if (route.waypoints.isEmpty) {
        return _mapService.findSafeRoute(origin: origin, destination: destination);
      }

      return route;
    } catch (_) {
      // No live route (offline, or the backend/tower is unreachable) — fall
      // back to a straight-line route if the area's tiles were cached, so
      // there's at least a bearing/direction to head in instead of nothing.
      return _mapService.findSafeRoute(origin: origin, destination: destination);
    }
  }
}
