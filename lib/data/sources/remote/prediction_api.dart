import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../models/prediction_model.dart';

class PredictionApi {
  const PredictionApi(this._client);

  final ApiClient _client;

  Future<PredictionResponseModel> predictFlood({
    required Map<String, Object?> payload,
  }) async {
    final response = await _client.post(
      ApiEndpoints.floodPrediction,
      body: payload,
    );
    return PredictionResponseModel.fromJson(response);
  }

  Future<PredictionResponseModel> predictLandslide({
    required Map<String, Object?> payload,
  }) async {
    final response = await _client.post(
      ApiEndpoints.landslidePrediction,
      body: payload,
    );
    return PredictionResponseModel.fromJson(response);
  }

  Future<PredictionResponseModel> fetchPredictions({String? hazardType}) async {
    final payload = await _client.get(
      ApiEndpoints.predictions,
      queryParameters: {'hazard_type': ?hazardType},
    );
    return PredictionResponseModel.fromJson(payload);
  }
}
