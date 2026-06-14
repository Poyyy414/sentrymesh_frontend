import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/location_service.dart';
import '../../models/rescue_location_model.dart';
import '../../models/rescue_request_model.dart';
import '../../../shared/enums/rescue_status.dart';

class RescueApi {
  const RescueApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> createRequest(RescueRequestModel request) {
    return _client.post(
      ApiEndpoints.rescueRequests,
      body: request.toCreateJson(),
    );
  }

  Future<Map<String, Object?>> fetchRequests() {
    return _client.get(ApiEndpoints.rescueRequests);
  }

  Future<Map<String, Object?>> fetchRequest(String id) {
    return _client.get(ApiEndpoints.rescueRequestById(id));
  }

  Future<Map<String, Object?>> fetchRequestLocation(String id) {
    return _client.get(ApiEndpoints.rescueRequestLocation(id));
  }

  Future<Map<String, Object?>> updateRequestStatus({
    required String id,
    required RescueStatus status,
  }) {
    return _client.patch(
      ApiEndpoints.rescueRequestStatus(id),
      body: {'status': status.name},
    );
  }

  Future<Map<String, Object?>> fetchRequestNavigation({
    required String id,
    required GeoPoint responderLocation,
  }) {
    return _client.get(
      ApiEndpoints.rescueRequestNavigation(id),
      queryParameters: {
        'responder_lat': responderLocation.latitude.toString(),
        'responder_lng': responderLocation.longitude.toString(),
      },
    );
  }

  Future<Map<String, Object?>> updateRequestLocation({
    required String id,
    required RescueLocationModel location,
  }) {
    return _client.patch(
      ApiEndpoints.rescueRequestLocation(id),
      body: location.toJson(),
    );
  }
}
