import '../../core/services/location_service.dart';
import '../../core/services/map_service.dart';
import '../models/route_model.dart';
import '../sources/remote/map_api.dart';

class MapRepository {
  const MapRepository({
    required MapApi remote,
    required MapService mapService,
  })  : _remote = remote,
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
      return RouteModel.fromJson(payload);
    } catch (_) {
      return _mapService.findSafeRoute(
        origin: origin,
        destination: destination,
      );
    }
  }
}
