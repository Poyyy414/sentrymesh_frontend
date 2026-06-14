import '../../core/services/location_service.dart';
import '../models/route_model.dart';
import '../sources/remote/map_api.dart';

class MapRepository {
  const MapRepository({required MapApi remote}) : _remote = remote;

  final MapApi _remote;

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
        return null;
      }

      return route;
    } catch (_) {
      return null;
    }
  }
}
