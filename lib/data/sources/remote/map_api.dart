import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/location_service.dart';

class MapApi {
  const MapApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> fetchSafeRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    return _client.get(
      ApiEndpoints.safeRoutes,
      queryParameters: {
        'origin_lat': origin.latitude.toString(),
        'origin_lng': origin.longitude.toString(),
        'destination_lat': destination.latitude.toString(),
        'destination_lng': destination.longitude.toString(),
      },
    );
  }
}
