import '../../data/models/route_model.dart';
import 'location_service.dart';
import 'offline/offline_map_cache.dart';

class MapService {
  const MapService({required this.offlineMapCache});

  final OfflineMapCache offlineMapCache;

  Future<RouteModel?> findSafeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    final hasCachedTiles = await offlineMapCache.hasCoverageFor(origin);
    if (!hasCachedTiles) {
      return null;
    }

    return RouteModel(
      id: 'offline-route',
      label: 'Cached safe route',
      distanceKm: 0,
      estimatedMinutes: 0,
      riskLevel: 'Unknown',
      waypoints: [origin, destination],
    );
  }
}
