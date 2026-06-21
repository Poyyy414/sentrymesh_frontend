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
    String? responderId,
  }) {
    final body = <String, Object?>{'status': status.name};
    if (responderId != null) {
      body['responder_id'] = responderId;
    }

    return _client.patch(ApiEndpoints.rescueRequestStatus(id), body: body);
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

  Future<Map<String, Object?>> fetchEvacuationCenters() {
    return _client.get(ApiEndpoints.evacuationCenters);
  }

  Future<Map<String, Object?>> deleteEvacuationCenter(String id) {
    return _client.delete(ApiEndpoints.evacuationCenterById(id));
  }

  Future<Map<String, Object?>> assignShelter({
    required String id,
    required String shelterId,
    required String shelterName,
    String? shelterAddress,
  }) {
    return _client.patch(
      ApiEndpoints.rescueRequestShelter(id),
      body: {
        'shelter_id': shelterId,
        'shelter_name': shelterName,
        'shelter_address': shelterAddress,
      },
    );
  }

  Future<Map<String, Object?>> assignResponder({
    required String id,
    required String responderId,
    required String responderName,
  }) {
    return _client.patch(
      ApiEndpoints.rescueRequestResponder(id),
      body: {'responder_id': responderId, 'responder_name': responderName},
    );
  }
}
