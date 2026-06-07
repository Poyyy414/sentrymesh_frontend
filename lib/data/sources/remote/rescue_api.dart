import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/rescue_request_model.dart';

class RescueApi {
  const RescueApi(this._client);

  final ApiClient _client;

  Future<Map<String, Object?>> createRequest(RescueRequestModel request) {
    return _client.post(ApiEndpoints.rescueRequests, body: request.toJson());
  }
}
